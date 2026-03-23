import 'package:flutter/material.dart';
import '../../../models/post_model.dart';

/// Shows posts that are within their active time window (24h / 36h / lifetime's first 24h).
class RecentsSection extends StatelessWidget {
  final List<PostModel> posts;

  const RecentsSection({super.key, required this.posts});

  List<PostModel> get _recentPosts =>
      posts.where((p) => p.isInRecentsWindow).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentPosts = _recentPosts;

    if (recentPosts.isEmpty) {
      return _EmptySection(
        icon: Icons.history_rounded,
        message: 'Nothing recent.\nPost something — it shows up here.',
        isDark: isDark,
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: recentPosts.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      ),
      itemBuilder: (context, i) => _RecentPostTile(
        post: recentPosts[i],
        isDark: isDark,
      ),
    );
  }
}

class _RecentPostTile extends StatelessWidget {
  final PostModel post;
  final bool isDark;

  const _RecentPostTile({required this.post, required this.isDark});

  String get _durationLabel {
    switch (post.duration) {
      case PostDuration.h24:
        return '24h';
      case PostDuration.h36:
        return '36h';
      case PostDuration.lifetime:
        return 'Lifetime';
    }
  }

  Color get _durationColor {
    switch (post.duration) {
      case PostDuration.h24:
        return const Color(0xFFFF6B6B);
      case PostDuration.h36:
        return const Color(0xFFFF9F43);
      case PostDuration.lifetime:
        return const Color(0xFF2B8EFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail or text preview
          if (post.type == PostType.media && post.imagePaths.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                post.imagePaths.first,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.text_fields_rounded,
                  color: subColor,
                  size: 28,
                ),
              ),
            ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Duration badge + time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _durationColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _durationColor.withValues(alpha: 0.35), width: 1),
                      ),
                      child: Text(
                        _durationLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _durationColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      post.relativeTime,
                      style: TextStyle(fontSize: 11.5, color: subColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  post.text.isEmpty ? '📷 Photo post' : post.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 13, color: subColor),
                    const SizedBox(width: 3),
                    Text('${post.likes}',
                        style: TextStyle(fontSize: 11.5, color: subColor)),
                    const SizedBox(width: 10),
                    Icon(Icons.visibility_outlined,
                        size: 13, color: subColor),
                    const SizedBox(width: 3),
                    Text('${post.views}',
                        style: TextStyle(fontSize: 11.5, color: subColor)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state placeholder for sections with no content.
class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isDark;

  const _EmptySection(
      {required this.icon, required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 38, color: isDark ? Colors.white30 : Colors.black26),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white38 : Colors.black38,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
