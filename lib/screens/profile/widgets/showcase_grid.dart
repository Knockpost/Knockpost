import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/system_nav_bar_fill.dart';
import '../../post/post_card.dart';
import '../../thoughts/thought_card.dart';
import 'profile_ui_helpers.dart';

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

  List<PostModel> get _showcasePosts =>
      posts
          .where((p) => p.isInShowcase && (p.type == PostType.media || p.type == PostType.waves) && p.imagePaths.isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showcasePosts = _showcasePosts;

    if (showcasePosts.isEmpty) {
      return ProfileEmptySection(
        icon: Icons.grid_view_rounded,
        message: 'Showcase is empty',
        subtitle: isOwnProfile
            ? 'Pin your best moments'
            : 'No highlights added yet',
        gradientColors: const [Color(0xFF5B9BFF), Color(0xFF2B8EFF)],
        tabController: tabController,
        tabIndex: 1,
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: showcasePosts.length,
      itemBuilder: (context, i) {
        final post = showcasePosts[i];
        return GestureDetector(
          onTap: () => _openShowcaseDetail(context, showcasePosts, i),
          child: _GridTile(post: post, isDark: isDark),
        );
      },
    );
  }

  void _openShowcaseDetail(
      BuildContext context, List<PostModel> posts, int startIndex) {
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
    if ((post.type == PostType.media || post.type == PostType.waves) && post.imagePaths.isNotEmpty) {
      final imagePath = post.imagePaths.first;
      final hasVideoExtension = imagePath.toLowerCase().endsWith('.mp4') || imagePath.toLowerCase().endsWith('.mov') || imagePath.toLowerCase().endsWith('.mkv');
      final isVideo = hasVideoExtension || post.type == PostType.waves;
      
      Widget imageWidget;
      if (isVideo) {
        imageWidget = Container(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
          child: Center(
            child: Icon(Icons.videocam, color: isDark ? Colors.white54 : Colors.black54, size: 32),
          ),
        );
      } else {
        imageWidget = imagePath.startsWith('assets/')
            ? Image.asset(imagePath, fit: BoxFit.cover)
            : Image.file(File(imagePath), fit: BoxFit.cover);
      }

      return Stack(
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

  // Keys attached to each post item so we can scroll to the tapped one
  late final List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.posts.length, (_) => GlobalKey());

    // After the first frame, scroll to the tapped post
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToStartIndex();
    });
  }

  void _scrollToStartIndex() {
    if (widget.startIndex == 0) return;
    final key = _itemKeys[widget.startIndex];
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: Duration.zero,
        alignment: 0.0, // top of viewport
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: bg,
              surfaceTintColor: bg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: isDark ? Colors.white : Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Posts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            body: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: widget.posts.length,
              itemBuilder: (context, i) {
                final post = widget.posts[i];
                final isLast = i == widget.posts.length - 1;
                final dividerColor = isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE8E8E8);
                final divider = Divider(height: 1, thickness: 1, color: dividerColor);

                return Column(
                  key: _itemKeys[i],
                  children: [
                    divider,
                    post.imagePaths.isEmpty
                        ? ThoughtCard(
                            user: widget.user,
                            text: post.text,
                            likes: post.likes,
                            views: post.views,
                          )
                        : PostCard(
                            imagePaths: post.imagePaths,
                            user: widget.user,
                            caption: post.text,
                            musicUrl: post.musicUrl,
                            musicTitle: post.musicTitle,
                            musicArtist: post.musicArtist,
                            isVideoPost: post.type == PostType.waves,
                            likes: post.likes,
                            views: post.views,
                          ),
                    if (isLast) divider,
                  ],
                );
              },
            ),
          ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }
}
