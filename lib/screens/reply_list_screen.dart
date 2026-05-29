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

    if (threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No replies yet',
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Private replies will appear here',
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
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
