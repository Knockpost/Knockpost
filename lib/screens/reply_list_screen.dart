import 'package:flutter/material.dart';

import '../models/reply_thread.dart';
import '../models/user_model.dart';
import '../widgets/reply_list_item.dart';

class ReplyListScreen extends StatelessWidget {
  final List<ReplyThread> threads;
  final UserModel Function(String userId) resolveUser;
  final ValueChanged<ReplyThread> onThreadTap;

  const ReplyListScreen({
    super.key,
    required this.threads,
    required this.resolveUser,
    required this.onThreadTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleColor = isDark ? const Color(0xFF6E6E6E) : const Color(0xFF9A9A9A);

    if (threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: subtleColor.withValues(alpha: 0.4),
                size: 28,
              ),
              const SizedBox(height: 14),
              Text(
                'No replies yet',
                style: TextStyle(
                  color: subtleColor.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('private-reply-author-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      itemCount: threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final thread = threads[index];
        final user = resolveUser(thread.userId);
        return ReplyListItem(
          thread: thread,
          user: user,
          onTap: () => onThreadTap(thread),
        );
      },
    );
  }
}
