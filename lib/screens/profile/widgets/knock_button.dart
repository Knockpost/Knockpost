import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../../../utils/global_knock_state.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';
import '../../../services/connection_service.dart';

/// Knock button with instant acceptance for open profiles and pending for private.
/// Designed to be used inside an Expanded widget, matching Edit button sizing.
class KnockButton extends StatefulWidget {
  final String userId;
  final KnockStatus initialStatus;
  final PrivacyType privacyType;
  final AccountType accountType;
  final bool isOwnProfile;
  final bool isCompact;
  final ValueChanged<KnockStatus>? onStatusChanged;

  const KnockButton({
    super.key,
    required this.userId,
    required this.initialStatus,
    this.privacyType = PrivacyType.open,
    this.accountType = AccountType.normal,
    this.isOwnProfile = false,
    this.isCompact = false,
    this.onStatusChanged,
  });

  @override
  State<KnockButton> createState() => _KnockButtonState();
}

class _KnockButtonState extends State<KnockButton>
    with SingleTickerProviderStateMixin {
  late ValueNotifier<KnockStatus> _globalNotifier;
  late KnockStatus _status;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _globalNotifier = GlobalKnockState.getNotifier(widget.userId, widget.initialStatus);
    _status = _globalNotifier.value;
    _globalNotifier.addListener(_onGlobalChange);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleController;
  }

  void _onGlobalChange() {
    if (mounted && _status != _globalNotifier.value) {
      setState(() => _status = _globalNotifier.value);
    }
  }

  @override
  void dispose() {
    _globalNotifier.removeListener(_onGlobalChange);
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KnockButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _globalNotifier.removeListener(_onGlobalChange);
      _globalNotifier = GlobalKnockState.getNotifier(widget.userId, widget.initialStatus);
      _status = _globalNotifier.value;
      _globalNotifier.addListener(_onGlobalChange);
    }
  }

  /// Whether the profile is effectively open (open privacy OR creator/professional account)
  bool get _isEffectivelyOpen =>
      widget.accountType == AccountType.creator ||
      widget.privacyType == PrivacyType.open;

  void _onTap() async {
    if (_isLoading) return;
    KnockHaptics.tap();
    _scaleController.reverse().then((_) => _scaleController.forward());

    // Compute the optimistic next status
    KnockStatus nextStatus = _status;
    switch (_status) {
      case KnockStatus.none:
      case KnockStatus.theyKnockedYouPending:
        nextStatus = _isEffectivelyOpen
            ? KnockStatus.knocked
            : KnockStatus.pending;
        break;
      case KnockStatus.pending:
      case KnockStatus.knocked:
      case KnockStatus.mutualKnocked:
        nextStatus = KnockStatus.none;
        break;
      case KnockStatus.theyKnockedYou:
        nextStatus = KnockStatus.mutualKnocked;
        break;
    }

    // Optimistic UI update
    final previousStatus = _status;
    setState(() {
      _status = nextStatus;
      _isLoading = true;
    });
    _globalNotifier.value = nextStatus;
    widget.onStatusChanged?.call(_status);

    // Persist to Firestore
    try {
      switch (previousStatus) {
        case KnockStatus.none:
        case KnockStatus.theyKnockedYouPending:
          await ConnectionService.instance.sendKnock(
            toUid: widget.userId,
            isOpenProfile: _isEffectivelyOpen,
          );
          break;
        case KnockStatus.pending:
        case KnockStatus.knocked:
        case KnockStatus.mutualKnocked:
          await ConnectionService.instance.removeKnock(widget.userId);
          break;
        case KnockStatus.theyKnockedYou:
          await ConnectionService.instance.acceptKnock(widget.userId);
          break;
      }
    } catch (_) {
      // Rollback on error
      if (mounted) {
        setState(() => _status = previousStatus);
        _globalNotifier.value = previousStatus;
        widget.onStatusChanged?.call(previousStatus);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwnProfile) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Label & colors ──────────────────────────────────────────────────────
    String label;
    Color bg;
    Color fg;
    Color borderColor;

    // Grey style (matches Edit button)
    final greyBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E5);
    final greyBorder = isDark ? Colors.white12 : Colors.black12;
    final greyFg = isDark ? Colors.white : Colors.black;

    // Primary style (full black / white)
    final primaryBg = isDark ? Colors.white : Colors.black;
    final primaryFg = isDark ? Colors.black : Colors.white;

    switch (_status) {
      case KnockStatus.none:
      case KnockStatus.theyKnockedYouPending:
        label = 'Knock';
        bg = primaryBg;
        fg = primaryFg;
        borderColor = greyBorder;
        break;
      case KnockStatus.pending:
        label = 'Pending';
        bg = greyBg;
        fg = greyFg;
        borderColor = greyBorder;
        break;
      case KnockStatus.knocked:
        label = 'Knocked';
        bg = greyBg;
        fg = greyFg;
        borderColor = greyBorder;
        break;
      case KnockStatus.theyKnockedYou:
        label = 'Knock Back';
        bg = primaryBg;
        fg = primaryFg;
        borderColor = greyBorder;
        break;
      case KnockStatus.mutualKnocked:
        label = 'Knocked';
        bg = greyBg;
        fg = greyFg;
        borderColor = greyBorder;
        break;
    }

    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: widget.isCompact ? 5 : 8,
            horizontal: widget.isCompact ? 12 : 0,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.isCompact ? 8 : 12),
            border: Border.all(
              color: borderColor,
            ),
          ),
          alignment: Alignment.center,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: KnockpostLoadingIndicator(),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: widget.isCompact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}
