import 'package:flutter/material.dart';
import 'dart:async';
import 'knockpost_avatar.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOM IN-APP NOTIFICATION BANNER v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Instagram-quality in-app notification banner:
//   • Slide-in from top with spring animation
//   • Profile image + action text (never robotic titles)
//   • Duplicate prevention: only one banner shown at a time
//   • Swipe up to dismiss
//   • Auto-dismiss after 3.5 seconds
//   • Haptic feedback on tap
// ═══════════════════════════════════════════════════════════════════════════════

class CustomInAppNotification extends StatefulWidget {
  final String title;
  final String body;
  final String type;
  final String? profileImageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const CustomInAppNotification({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    this.profileImageUrl,
    this.onTap,
    this.onDismiss,
  });

  // ── Active banner tracking (prevents duplicate banners) ──
  static OverlayEntry? _currentEntry;
  static Timer? _autoDismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required String type,
    String? profileImageUrl,
    VoidCallback? onTap,
  }) {
    // Dismiss any existing banner first (prevents stacking)
    _dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: CustomInAppNotification(
            title: title,
            body: body,
            type: type,
            profileImageUrl: profileImageUrl,
            onTap: () {
              if (onTap != null) onTap();
              _dismiss();
            },
            onDismiss: _dismiss,
          ),
        ),
      ),
    );

    overlay.insert(_currentEntry!);

    // Auto dismiss after 3.5 seconds
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(milliseconds: 3500), _dismiss);
  }

  static void _dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
    }
    _currentEntry = null;
  }

  @override
  State<CustomInAppNotification> createState() => _CustomInAppNotificationState();
}

class _CustomInAppNotificationState extends State<CustomInAppNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIconForType() {
    switch (widget.type.toLowerCase()) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'like':
      case 'wavelike':
        return Icons.favorite_border;
      case 'comment':
        return Icons.reply_rounded;
      case 'knock':
      case 'knockaccept':
      case 'knockback':
        return Icons.front_hand_outlined;
      case 'mention':
        return Icons.alternate_email_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
              widget.onDismiss?.call();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 40,
                    offset: const Offset(0, 2),
                  ),
              ],
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App icon or profile image
                if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty)
                  KnockpostAvatar(
                    url: widget.profileImageUrl!,
                    radius: 19,
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForType(),
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 18,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App name label
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Subtle time indicator
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'now',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
