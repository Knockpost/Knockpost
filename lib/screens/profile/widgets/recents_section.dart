import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/post_card.dart';
import '../../../widgets/thought_card.dart';
import '../../../utils/global_post_state.dart';
import 'profile_ui_helpers.dart';

/// Shows posts that are within their 3-day active window.
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
    return ValueListenableBuilder<Set<String>>(
      valueListenable: GlobalPostState.deletedPostIds,
      builder: (context, deletedIds, _) {
        final recentPosts = _recentPosts.where((p) => !deletedIds.contains(p.id)).toList();

        if (recentPosts.isEmpty) {
          return ProfileEmptySection(
            icon: Icons.history_rounded,
            message: 'No recent posts',
            subtitle: isOwnProfile
                ? 'Your posts from the last 72h will appear here'
                : 'No recent activity to show',
            gradientColors: const [Color(0xFF64B5F6), Color(0xFF1E88E5)],
            tabController: tabController,
            tabIndex: 0,
          );
        }

        final dividerColor = isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFE8E8E8);

        final divider = Divider(height: 1, thickness: 1, color: dividerColor);

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: recentPosts.length,
          itemBuilder: (context, i) {
            final post = recentPosts[i];
            final isLast = i == recentPosts.length - 1;

            Widget content;
            if (post.type == PostType.media && post.imagePaths.isNotEmpty) {
              content = PostCard(
                imagePaths: post.imagePaths,
                user: user,
                caption: post.text,
                likes: post.likes,
                views: post.views,
                postId: post.id,
              );
            } else {
              content = ThoughtCard(
                user: user,
                text: post.text,
                likes: post.likes,
                views: post.views,
                postId: post.id,
              );
            }

            return Column(
              children: [
                divider,
                content,
                if (isLast) divider,
              ],
            );
          },
        );
      },
    );
  }
}
