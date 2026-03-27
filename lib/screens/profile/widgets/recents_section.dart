import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/post_card.dart';
import 'profile_ui_helpers.dart';

/// Shows posts that are within their 3-day active window.
/// Renders each post using the same PostCard widget as the home feed.
class RecentsSection extends StatelessWidget {
  final List<PostModel> posts;
  final UserModel user;
  final TabController? tabController;
  final bool isOwnProfile;

  const RecentsSection({
    super.key,
    required this.posts,
    required this.user,
    this.tabController,
    this.isOwnProfile = true,
  });

  List<PostModel> get _recentPosts =>
      posts.where((p) => p.isInRecentsWindow).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentPosts = _recentPosts;

    if (recentPosts.isEmpty) {
      return ProfileEmptySection(
        icon: Icons.history_rounded,
        message: 'Nothing recent',
        subtitle: isOwnProfile
            ? 'Share a recent moment'
            : 'No recent moments yet',
        gradientColors: const [Color(0xFFFF9F43), Color(0xFFFF6B6B)],
        tabController: tabController,
        tabIndex: 0,
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: recentPosts.length,
      separatorBuilder: (_, __) => Divider(
        thickness: 6,
        height: 6,
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF0F0F0),
      ),
      itemBuilder: (context, i) {
        final post = recentPosts[i];
        if (post.type == PostType.media && post.imagePaths.isNotEmpty) {
          return PostCard(
            imagePaths: post.imagePaths,
            user: user,
            caption: post.text,
          );
        }
        // Text-only post — render as a styled text card
        return _TextOnlyRecentCard(post: post, user: user, isDark: isDark);
      },
    );
  }
}

/// A home-feed-style card for text-only posts in the Recents section.
class _TextOnlyRecentCard extends StatelessWidget {
  final PostModel post;
  final UserModel user;
  final bool isDark;

  const _TextOnlyRecentCard({
    required this.post,
    required this.user,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Caption / text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              post.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Meta row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  post.relativeTime,
                  style: TextStyle(fontSize: 11.5, color: subColor),
                ),
                const SizedBox(width: 12),
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
                const Spacer(),
                _DurationChip(duration: post.duration, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small coloured chip showing post duration type.
class _DurationChip extends StatelessWidget {
  final PostDuration duration;
  final bool isDark;

  const _DurationChip({required this.duration, required this.isDark});

  String get label {
    switch (duration) {
      case PostDuration.h24:
        return '24h';
      case PostDuration.h36:
        return '36h';
      case PostDuration.lifetime:
        return '∞';
    }
  }

  Color get color {
    switch (duration) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
