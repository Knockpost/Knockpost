import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import 'profile_ui_helpers.dart';

/// Grid view of lifetime posts (Showcase tab).
/// Tapping a post opens it in a full-screen scroll detail view.
class ShowcaseGrid extends StatelessWidget {
  final List<PostModel> posts;
  final TabController? tabController;
  final bool isOwnProfile;

  const ShowcaseGrid({
    super.key,
    required this.posts,
    this.tabController,
    this.isOwnProfile = true,
  });

  List<PostModel> get _showcasePosts =>
      posts
          .where((p) => p.isInShowcase)
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
        builder: (_) =>
            _ShowcaseDetailScreen(posts: posts, startIndex: startIndex),
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
    if (post.type == PostType.media && post.imagePaths.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(post.imagePaths.first, fit: BoxFit.cover),
          if (post.imagePaths.length > 1)
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
                  Icons.copy_rounded,
                  color: Colors.white,
                  size: 12,
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

/// Full-screen scrollable detail view opened from the showcase grid
class _ShowcaseDetailScreen extends StatefulWidget {
  final List<PostModel> posts;
  final int startIndex;

  const _ShowcaseDetailScreen(
      {required this.posts, required this.startIndex});

  @override
  State<_ShowcaseDetailScreen> createState() => _ShowcaseDetailScreenState();
}

class _ShowcaseDetailScreenState extends State<_ShowcaseDetailScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Showcase',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (context, i) {
          final post = widget.posts[i];
          return _ShowcasePostView(post: post, isDark: isDark);
        },
      ),
    );
  }
}

class _ShowcasePostView extends StatelessWidget {
  final PostModel post;
  final bool isDark;

  const _ShowcasePostView({required this.post, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white60 : Colors.black45;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.type == PostType.media && post.imagePaths.isNotEmpty)
            ...post.imagePaths.map(
              (img) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Image.asset(img,
                    fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.text.isNotEmpty)
                  Text(
                    post.text,
                    style: TextStyle(
                        fontSize: 15, color: textColor, height: 1.5),
                  ),
                const SizedBox(height: 10),
                Text(
                  post.relativeTime,
                  style: TextStyle(fontSize: 11.5, color: subColor),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 18, color: subColor),
                    const SizedBox(width: 4),
                    Text('${post.likes}',
                        style: TextStyle(fontSize: 13, color: subColor)),
                    const SizedBox(width: 14),
                    Icon(Icons.visibility_outlined,
                        size: 18, color: subColor),
                    const SizedBox(width: 4),
                    Text('${post.views}',
                        style: TextStyle(fontSize: 13, color: subColor)),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
