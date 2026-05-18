import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/post_scroll_lock_scope.dart';
import '../../../widgets/system_nav_bar_fill.dart';
import '../../post/post_card.dart';
import '../../thoughts/thought_card.dart';
import '../../../utils/global_post_state.dart';
import '../../../utils/haptic_helper.dart';
import '../../../widgets/staggered_entry_animation.dart';
import 'profile_glimps_strip.dart';
import 'profile_ui_helpers.dart';
import 'package:video_player/video_player.dart';
import '../../../utils/image_helper.dart';
import '../../waves/waves_feed_card.dart';

/// Grid view of lifetime posts (Showcase tab).
/// Tapping a post opens it in a full-screen scroll detail view.
class ShowcaseGrid extends StatelessWidget {
  final List<PostModel> posts;
  final UserModel user;
  final TabController? tabController;
  final bool isOwnProfile;

  const ShowcaseGrid({
    super.key,
    required this.posts,
    required this.user,
    this.tabController,
    this.isOwnProfile = true,
  });

  List<PostModel> get _showcaseGridPosts =>
      posts
          .where(
            (p) =>
                p.isInShowcase &&
                (p.type == PostType.media || p.type == PostType.waves) &&
                p.imagePaths.isNotEmpty,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<PostModel> get _showcaseGlimpses =>
      posts
          .where(
            (p) =>
                p.isInShowcase &&
                p.type == PostType.glimps &&
                p.imagePaths.isNotEmpty,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: GlobalPostState.deletedPostIds,
      builder: (context, deletedIds, _) {
        final gridPosts = _showcaseGridPosts
            .where((p) => !deletedIds.contains(p.id))
            .toList();
        final glimpses = _showcaseGlimpses
            .where((p) => !deletedIds.contains(p.id))
            .toList();

        if (gridPosts.isEmpty && glimpses.isEmpty) {
          return ProfileEmptySection(
            icon: Icons.grid_view_rounded,
            message: 'Showcase is empty',
            subtitle: isOwnProfile
                ? 'Pin your best moments'
                : 'No highlights added yet',
            gradientColors: const [Color(0xFFFFA726), Color(0xFFFF7043)],
            tabController: tabController,
            tabIndex: 1,
          );
        }

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
            if (gridPosts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Posts",
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
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: gridPosts.length,
                itemBuilder: (context, i) {
                  final post = gridPosts[i];
                  return StaggeredEntryAnimation(
                    index:
                        i %
                        12, // Repeat animation for extremely large grids to prevent huge delays
                    delay: const Duration(milliseconds: 40),
                    child: GestureDetector(
                      onTap: () => _openShowcaseDetail(context, gridPosts, i),
                      child: _GridTile(post: post, isDark: isDark),
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

  void _openShowcaseDetail(
    BuildContext context,
    List<PostModel> posts,
    int startIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShowcaseDetailScreen(
          posts: posts,
          user: user,
          startIndex: startIndex,
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final PostModel post;
  final bool isDark;

  const _GridTile({required this.post, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if ((post.type == PostType.media || post.type == PostType.waves) &&
        post.imagePaths.isNotEmpty) {
      final imagePath = post.imagePaths.first;
      final hasVideoExtension =
          imagePath.toLowerCase().endsWith('.mp4') ||
          imagePath.toLowerCase().endsWith('.mov') ||
          imagePath.toLowerCase().endsWith('.mkv');
      final isVideo = hasVideoExtension || post.type == PostType.waves;

      Widget imageWidget;
      if (isVideo) {
        imageWidget = _VideoThumbnail(path: imagePath);
      } else {
        final provider = ImageHelper.resolveImage(imagePath);
        imageWidget = provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Container(color: Colors.grey);
      }

      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (post.type == PostType.waves)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            if (post.imagePaths.length > 1 && post.type == PostType.media)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.collections_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    // Text post tile
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Text(
          post.text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String path;

  const _VideoThumbnail({required this.path});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.path.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.path));
    } else if (widget.path.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(widget.path);
    } else {
      _controller = VideoPlayerController.file(File(widget.path));
    }

    _controller
        .initialize()
        .then((_) {
          if (mounted) {
            _controller.setVolume(0);
            _controller.setLooping(true);
            _controller.play();
            setState(() => _initialized = true);
          }
        })
        .catchError((_) {
          // Ignored for thumbnail
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.white54, size: 32),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen scrollable detail view — Instagram-style PostCard list
// ─────────────────────────────────────────────────────────────────────────────

class _ShowcaseDetailScreen extends StatefulWidget {
  final List<PostModel> posts;
  final UserModel user;
  final int startIndex;

  const _ShowcaseDetailScreen({
    required this.posts,
    required this.user,
    required this.startIndex,
  });

  @override
  State<_ShowcaseDetailScreen> createState() => _ShowcaseDetailScreenState();
}

class _ShowcaseDetailScreenState extends State<_ShowcaseDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PostScrollLockController _postScrollLockController;
  late final Key _centerKey = const ValueKey('center');
  double _scrollDelta = 0;
  bool _showNavBar = true;

  @override
  void initState() {
    super.initState();
    _postScrollLockController = PostScrollLockController()
      ..register(_scrollController);
  }

  @override
  void dispose() {
    _postScrollLockController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final dy = notification.scrollDelta ?? 0;
      if (dy > 0) {
        _scrollDelta += dy;
        if (_scrollDelta > 50 && _showNavBar) {
          setState(() => _showNavBar = false);
        }
      } else if (dy < 0) {
        _scrollDelta = 0;
        if (!_showNavBar) {
          setState(() => _showNavBar = true);
        }
      }
    }
    return false;
  }

  Widget _buildPostItem(int i, bool isDark) {
    if (i < 0 || i >= widget.posts.length) return const SizedBox.shrink();
    final post = widget.posts[i];
    final isLast = i == widget.posts.length - 1;
    final dividerColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE8E8E8);
    final divider = Divider(height: 1, thickness: 1, color: dividerColor);

    return Column(
      children: [
        divider,
        post.type == PostType.waves
            ? WavesFeedCard(
                post: post,
                user: widget.user,
                onTap: () {
                  // Optional: handle tap if needed, though usually not required in profile
                },
              )
            : post.imagePaths.isEmpty
            ? ThoughtCard(
                user: widget.user,
                text: post.text,
                likes: post.likes,
                views: post.views,
                disableProfileNavigation: false,
                timestamp: post.timestampText,
              )
            : PostCard(
                imagePaths: post.imagePaths,
                user: widget.user,
                caption: post.text,
                postId: post.id,
                musicUrl: post.musicUrl,
                musicTitle: post.musicTitle,
                musicArtist: post.musicArtist,
                musicStyle: post.musicStyle,
                musicCoverUrl: post.musicCoverUrl,
                musicTrimStart: post.musicTrimStart,
                musicLyrics: post.musicLyrics,
                musicLyricsConfig: post.musicLyricsConfig,
                musicOverlayX: post.musicOverlayX,
                musicOverlayY: post.musicOverlayY,
                musicOverlayScale: post.musicOverlayScale,
                musicOverlayRotation: post.musicOverlayRotation,
                filterIndex: post.filterIndex,
                textOverlays: post.textOverlays,
                drawPaths: post.drawPaths,
                isVideoPost: post.isVideoPost,
                videoHasSound: post.videoHasSound,
                coverImagePath: post.coverImagePath,
                mediaAspectRatio: post.mediaAspectRatio,
                mediaIsBaked: post.mediaIsBaked,
                likes: post.likes,
                views: post.views,
                disableProfileNavigation: false,
                timestamp: post.timestampText,
              ),
        if (isLast) divider,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: bg,
              surfaceTintColor: bg,
              elevation: 0,
              titleSpacing: 0,
              leadingWidth: 46,
              leading: IconButton(
                padding: const EdgeInsets.only(left: 8),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Showcase',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            body: PostScrollLockScope(
              controller: _postScrollLockController,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _postScrollLockController,
                  builder: (context, isScrollLocked, _) {
                    return CustomScrollView(
                      controller: _scrollController,
                      physics: isScrollLocked
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      center: _centerKey,
                      slivers: [
                        if (widget.startIndex > 0)
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final actualIndex =
                                  widget.startIndex - 1 - index;
                              return _buildPostItem(actualIndex, isDark);
                            }, childCount: widget.startIndex),
                          ),
                        SliverList(
                          key: _centerKey,
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final actualIndex = widget.startIndex + index;
                            return _buildPostItem(actualIndex, isDark);
                          }, childCount:
                              widget.posts.length - widget.startIndex),
                        ),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 40),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            opacity: _showNavBar ? 1.0 : 0.0,
            child: SystemNavBarFill(color: bg),
          ),
        ],
      ),
    );
  }
}
