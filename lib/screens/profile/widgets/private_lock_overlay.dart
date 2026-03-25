import 'package:flutter/material.dart';
import '../../../models/user_model.dart';

/// Overlay shown when a profile is locked until a knock is accepted.
class PrivateLockOverlay extends StatelessWidget {
  final KnockStatus knockStatus;
  final VoidCallback onKnock;

  const PrivateLockOverlay({
    super.key,
    required this.knockStatus,
    required this.onKnock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    final hasPendingKnock = knockStatus == KnockStatus.pending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lock icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline_rounded, size: 30, color: textColor),
          ),
          const SizedBox(height: 18),

          Text(
            'Profile Locked',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPendingKnock
                ? 'Your knock is pending.\nWaiting for them to accept.'
                : 'Send a Knock to unlock this profile.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: subColor, height: 1.45),
          ),
          const SizedBox(height: 24),

          if (!hasPendingKnock)
            GestureDetector(
              onTap: onKnock,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: textColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Send Knock',
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: subColor),
                const SizedBox(width: 6),
                Text(
                  'Knock sent',
                  style: TextStyle(
                    color: subColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
