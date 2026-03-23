import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';

/// Knock button with instant acceptance for open profiles and pending for private.
class KnockButton extends StatefulWidget {
  final KnockStatus initialStatus;
  final PrivacyType privacyType;
  final bool isOwnProfile;
  final ValueChanged<KnockStatus>? onStatusChanged;

  const KnockButton({
    super.key,
    required this.initialStatus,
    this.privacyType = PrivacyType.open,
    this.isOwnProfile = false,
    this.onStatusChanged,
  });

  @override
  State<KnockButton> createState() => _KnockButtonState();
}

class _KnockButtonState extends State<KnockButton>
    with SingleTickerProviderStateMixin {
  late KnockStatus _status;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleController;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KnockButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      _status = widget.initialStatus;
    }
  }

  void _onTap() {
    KnockHaptics.tap();
    _scaleController.reverse().then((_) => _scaleController.forward());

    setState(() {
      switch (_status) {
        case KnockStatus.none:
          _status = widget.privacyType == PrivacyType.open
              ? KnockStatus.knocked
              : KnockStatus.pending;
          break;
        case KnockStatus.pending:
        case KnockStatus.knocked:
        case KnockStatus.mutualKnocked:
          _status = KnockStatus.none;
          break;
        case KnockStatus.theyKnockedYou:
          _status = KnockStatus.mutualKnocked;
          break;
      }
    });

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

    switch (_status) {
      case KnockStatus.none:
        label = 'Knock';
        bg = isDark ? Colors.white : Colors.black;
        fg = isDark ? Colors.black : Colors.white;
        break;
      case KnockStatus.pending:
        label = 'Knocked';
        bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);
        fg = isDark ? Colors.white : Colors.black;
        break;
      case KnockStatus.knocked:
        label = 'Knocked';
        bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);
        fg = isDark ? Colors.white : Colors.black;
        break;
      case KnockStatus.theyKnockedYou:
        label = 'Knock Back';
        bg = isDark ? Colors.white : Colors.black;
        fg = isDark ? Colors.black : Colors.white;
        break;
      case KnockStatus.mutualKnocked:
        label = 'Knocked';
        bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);
        fg = isDark ? Colors.white : Colors.black;
        break;
    }

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.2,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
