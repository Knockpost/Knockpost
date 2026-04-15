import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../post/post_card.dart';
import '../../thoughts/thought_card.dart';
import '../../../utils/global_post_state.dart';
import '../../../widgets/staggered_entry_animation.dart';
import 'profile_glimps_strip.dart';
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

  List<PostModel> get _recentGlimpses =>
      posts.where((p) => p.isInRecentsWindow && p.type == PostType.glimps && p.imagePaths.isNotEmpty).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<PostModel> get _recentNormalPosts =>
      posts.where((p) => p.isInRecentsWindow && p.type != PostType.glimps).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: GlobalPostState.deletedPostIds,
      builder: (context, deletedIds, _) {
        final recentPosts = _recentNormalPosts.where((p) => !deletedIds.contains(p.id)).toList();
        final glimpses = _recentGlimpses.where((p) => !deletedIds.contains(p.id)).toList();

        if (recentPosts.isEmpty && glimpses.isEmpty) {
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glimpses.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 24, bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Glimpses",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              ProfileGlimpsStrip(glimpses: glimpses, user: user),
            ],
            if (recentPosts.isNotEmpty) ...[
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: recentPosts.length,
                itemBuilder: (context, i) {
                  final post = recentPosts[i];
                  final isLast = i == recentPosts.length - 1;

                  Widget content;
                  if ((post.type == PostType.media || post.type == PostType.waves) && post.imagePaths.isNotEmpty) {
                    content = PostCard(
                      imagePaths: post.imagePaths,
                      user: user,
                      caption: post.text,
                      likes: post.likes,
                      views: post.views,
                      postId: post.id,
                      disableProfileNavigation: true,
                      timestamp: post.timestampText,
                    );
                  } else {
                    content = ThoughtCard(
                      user: user,
                      text: post.text,
                      likes: post.likes,
                      views: post.views,
                      postId: post.id,
                      disableProfileNavigation: true,
                      timestamp: post.timestampText,
                    );
                  }

                  return StaggeredEntryAnimation(
                    index: i,
                    child: Column(
                      children: [
                        divider,
                        content,
                        if (isLast) divider,
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
