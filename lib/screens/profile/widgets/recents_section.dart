import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../post/post_card.dart';
import '../../thoughts/thought_card.dart';
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

    debugPrint('[RecentsSection] Total posts: ${posts.length}, Recent: ${recentPosts.length}');
    for (final p in recentPosts) {
      debugPrint('[RecentsSection] Post id=${p.id} type=${p.type} images=${p.imagePaths.length} text="${p.text.substring(0, p.text.length.clamp(0, 30))}"');
    }

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
        if ((post.type == PostType.media || post.type == PostType.waves) &&
            post.imagePaths.isNotEmpty) {
          content = PostCard(
            imagePaths: post.imagePaths,
            user: user,
            caption: post.text,
            musicUrl: post.musicUrl,
            musicTitle: post.musicTitle,
            musicArtist: post.musicArtist,
            isVideoPost: post.type == PostType.waves,
          );
        } else {
          content = ThoughtCard(
            user: user,
            text: post.text,
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
  }
}

