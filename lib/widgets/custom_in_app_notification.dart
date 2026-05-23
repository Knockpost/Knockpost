import 'package:flutter/material.dart';
import 'dart:async';
import 'knockpost_avatar.dart';

class CustomInAppNotification extends StatefulWidget {
  final String title;
  final String body;
  final String type;
  final String? profileImageUrl;
  final VoidCallback? onTap;

  const CustomInAppNotification({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    this.profileImageUrl,
    this.onTap,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required String type,
    String? profileImageUrl,
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: CustomInAppNotification(
            title: title,
            body: body,
            type: type,
            profileImageUrl: profileImageUrl,
            onTap: () {
              if (onTap != null) onTap();
              overlayEntry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  State<CustomInAppNotification> createState() => _CustomInAppNotificationState();
}

class _CustomInAppNotificationState extends State<CustomInAppNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        if (widget.onTap != null) widget.onTap!();
      }
    });
  }

  IconData _getIconForType() {
    switch (widget.type.toLowerCase()) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'like':
        return Icons.favorite_border;
      case 'comment':
        return Icons.comment_outlined;
      case 'knock':
        return Icons.front_hand_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _offsetAnimation,
      child: GestureDetector(
        onTap: _dismiss,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            _dismiss();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty)
                KnockpostAvatar(
                  url: widget.profileImageUrl!,
                  radius: 20,
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    _getIconForType(),
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
