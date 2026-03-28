import 'package:flutter/material.dart';
import '../../../utils/global_knock_state.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';

/// Knock button with instant acceptance for open profiles and pending for private.
/// Designed to be used inside an Expanded widget, matching Edit button sizing.
class KnockButton extends StatefulWidget {
  final String userId;
  final KnockStatus initialStatus;
  final PrivacyType privacyType;
  final AccountType accountType;
  final bool isOwnProfile;
  final ValueChanged<KnockStatus>? onStatusChanged;

  const KnockButton({
    super.key,
    required this.userId,
    required this.initialStatus,
    this.privacyType = PrivacyType.open,
    this.accountType = AccountType.normal,
    this.isOwnProfile = false,
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

  void _onTap() {
    KnockHaptics.tap();
    _scaleController.reverse().then((_) => _scaleController.forward());

    KnockStatus nextStatus = _status;
    switch (_status) {
      case KnockStatus.none:
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

    setState(() => _status = nextStatus);
    _globalNotifier.value = nextStatus;

    widget.onStatusChanged?.call(_status);
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
