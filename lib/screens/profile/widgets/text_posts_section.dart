import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import 'profile_ui_helpers.dart';

/// Scrollable list of text-only posts (Text tab on profile).
class TextPostsSection extends StatelessWidget {
  final List<PostModel> posts;
  final TabController? tabController;
  final bool isOwnProfile;

  const TextPostsSection({
    super.key,
    required this.posts,
    this.tabController,
    this.isOwnProfile = true,
  });

  List<PostModel> get _textPosts =>
      posts.where((p) => p.type == PostType.text).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPosts = _textPosts;

    if (textPosts.isEmpty) {
      return ProfileEmptySection(
        icon: Icons.format_quote_rounded,
        message: 'No thoughts yet',
        subtitle: isOwnProfile 
            ? 'Share what you feel' 
            : 'No thoughts shared yet',
        gradientColors: const [Color(0xFFB388FF), Color(0xFF7C4DFF)],
        tabController: tabController,
        tabIndex: 2,
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: textPosts.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      ),
      itemBuilder: (context, i) => _TextPostTile(
        post: textPosts[i],
        isDark: isDark,
      ),
    );
  }
}

class _TextPostTile extends StatefulWidget {
  final PostModel post;
  final bool isDark;

  const _TextPostTile({required this.post, required this.isDark});

  @override
  State<_TextPostTile> createState() => _TextPostTileState();
}

class _TextPostTileState extends State<_TextPostTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black;
    final subColor = widget.isDark ? Colors.white54 : Colors.black45;
    final accentColor = widget.isDark ? Colors.white60 : Colors.black45;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              firstChild: Text(
                widget.post.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              secondChild: Text(
                widget.post.text,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  widget.post.relativeTime,
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
                const SizedBox(width: 12),
                Icon(Icons.favorite_border_rounded,
                    size: 12, color: subColor),
                const SizedBox(width: 3),
                Text(
                  '${widget.post.likes}',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
                const SizedBox(width: 10),
                Icon(Icons.visibility_outlined, size: 12, color: subColor),
                const SizedBox(width: 3),
                Text(
                  '${widget.post.views}',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
                const Spacer(),
                _DurationChip(duration: widget.post.duration),
              ],
            ),
            if (!_expanded && widget.post.text.length > 100)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tap to read more',
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final PostDuration duration;

  const _DurationChip({required this.duration});

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
