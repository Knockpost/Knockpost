import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/post_card.dart';
import '../../../widgets/thought_card.dart';
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
        // Text-only post — render as a ThoughtCard
        return ThoughtCard(
          user: user,
          text: post.text,
        );
      },
    );
  }
}
