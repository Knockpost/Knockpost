import 'dart:io';

import 'package:flutter/material.dart';

import '../models/reply_thread.dart';
import '../models/user_model.dart';

class ReplyListItem extends StatelessWidget {
  final ReplyThread thread;
  final UserModel user;
  final VoidCallback onTap;

  const ReplyListItem({
    super.key,
    required this.thread,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAEAEA);
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final subtleColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF757575);
    final accent = isDark ? const Color(0xFFB9C1C9) : const Color(0xFF6E7C89);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor.withValues(alpha: 0.9)),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                backgroundImage: user.avatarAsset != null
                    ? (user.avatarAsset!.startsWith('assets/')
                          ? AssetImage(user.avatarAsset!) as ImageProvider
                          : FileImage(File(user.avatarAsset!)))
                    : null,
                child: user.avatarAsset == null
                    ? Icon(Icons.person_rounded, color: subtleColor, size: 22)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            user.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(thread.lastTimestamp),
                          style: TextStyle(
                            color: subtleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessage.isEmpty
                                ? 'Start a private conversation around this post'
                                : thread.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: thread.unreadCount > 0 ? textColor : subtleColor,
                              fontSize: 13.5,
                              fontWeight: thread.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (thread.unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }
    if (difference.inHours < 24 && now.day == timestamp.day) {
      return '${difference.inHours}h';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }
}
