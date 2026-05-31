import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../post/post_card.dart';
import '../../thoughts/thought_card.dart';
import '../../waves/waves_feed_card.dart';
import '../../../utils/global_post_state.dart';
import '../../../widgets/staggered_entry_animation.dart';
import 'daily_glimpse_strip.dart';
import '../../../services/daily_glimpse_service.dart';
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

  // Glimpses are now handled by DailyGlimpseService directly in build

  List<PostModel> get _recentNormalPosts =>
      posts.where((p) => p.isInRecentsWindow && p.type != PostType.glimps && p.type != PostType.waves).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<PostModel> get _recentWaves =>
      posts.where((p) => p.isInRecentsWindow && p.type == PostType.waves && p.imagePaths.isNotEmpty).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: GlobalPostState.deletedPostIds,
      builder: (context, deletedIds, _) {
        final validPosts = posts.where((p) => !deletedIds.contains(p.id)).toList();
        final recentPosts = _recentNormalPosts.where((p) => !deletedIds.contains(p.id)).toList();
        final waves = _recentWaves.where((p) => !deletedIds.contains(p.id)).toList();

        // Get all daily cards for the user, but only keep those that have at least one glimpse in the recents window
        final allGlimpses = validPosts.where((p) => p.type == PostType.glimps).toList();
        final allDailyCards = DailyGlimpseService.instance.getActiveDailyCards(allGlimpses);
        final recentDailyCards = allDailyCards.where((card) {
          final glimpses = DailyGlimpseService.instance.getGlimpsesForCard(card, validPosts);
          return glimpses.any((g) => g.isInRecentsWindow);
        }).toList();

        if (recentPosts.isEmpty && recentDailyCards.isEmpty && waves.isEmpty) {
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
            if (recentDailyCards.isNotEmpty) ...[
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
              DailyGlimpseStrip(
                dailyCards: recentDailyCards, 
                allUserGlimpses: validPosts, 
                user: user
              ),
            ],
            // ── Waves Section ──
            if (waves.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Waves",
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
              ...waves.map((wavePost) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WavesFeedCard(post: wavePost, user: user),
              )),
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
                  if (post.type == PostType.media && post.imagePaths.isNotEmpty) {
                    content = PostCard(
                      imagePaths: post.imagePaths,
                      optimizedImagePaths: post.optimizedImagePaths,
                      user: user,
                      caption: post.text,
                      likes: post.likes,
                      views: post.views,
                      postId: post.id,
                      disableProfileNavigation: true,
                      timestamp: post.timestampText,
                      musicUrl: post.musicUrl,
                      musicTitle: post.musicTitle,
                      musicArtist: post.musicArtist,
                      musicCoverUrl: post.musicCoverUrl,
                      musicTrimStart: post.musicTrimStart,
                      musicStickerConfig: post.musicStickerConfig,
                      musicVolume: post.musicVolume,
                      originalAudioVolume: post.originalAudioVolume,
                      filterIndex: post.filterIndex,
                      textOverlays: post.textOverlays,
                      drawPaths: post.drawPaths,
                      isVideoPost: post.isVideoPost,
                      videoHasSound: post.videoHasSound,
                      coverImagePath: post.coverImagePath,
                      mediaAspectRatio: post.mediaAspectRatio,
                      mediaIsBaked: post.mediaIsBaked,
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
