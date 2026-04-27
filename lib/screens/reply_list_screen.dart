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
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final subtleColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF757575);
    final cardColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);

    if (threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: subtleColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No private replies yet',
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When someone replies to this post, their conversation will appear here as a private 1-to-1 thread.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtleColor,
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('private-reply-author-list'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
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
