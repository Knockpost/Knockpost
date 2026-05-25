import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'post/post_card.dart';
import 'thoughts/thought_card.dart';
import '../widgets/comment_sheet.dart';
import '../widgets/post_scroll_lock_scope.dart';
import '../widgets/reactors_sheet.dart';

class SinglePostScreen extends StatefulWidget {
  final PostModel post;
  final UserModel author;
  final bool autoOpenComments;
  final bool autoOpenReactions;
  final bool isPostOwner;
  final String? initialThreadUserId;

  const SinglePostScreen({
    super.key,
    required this.post,
    required this.author,
    this.autoOpenComments = false,
    this.autoOpenReactions = false,
    this.isPostOwner = false,
    this.initialThreadUserId,
  });

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PostScrollLockController _postScrollLockController;

  @override
  void initState() {
    super.initState();
    _postScrollLockController = PostScrollLockController()
      ..register(_scrollController);
    if (widget.autoOpenComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CommentSheet.show(
          context,
          postId: widget.post.id,
          postAuthor: widget.author,
          isPostOwner: widget.isPostOwner,
          initialThreadUserId: widget.initialThreadUserId,
        );
      });
    } else if (widget.autoOpenReactions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ReactorsSheet.show(context, postId: widget.post.id);
      });
    }
  }

  @override
  void dispose() {
    _postScrollLockController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Post',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        body: PostScrollLockScope(
          controller: _postScrollLockController,
          child: ValueListenableBuilder<bool>(
            valueListenable: _postScrollLockController,
            builder: (context, isScrollLocked, _) {
              return ListView(
                controller: _scrollController,
                physics: isScrollLocked
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  widget.post.imagePaths.isEmpty
                      ? ThoughtCard(
                          postId: widget.post.id,
                          user: widget.author,
                          text: widget.post.text,
                          likes: widget.post.likes,
                          views: widget.post.views,
                          timestamp: widget.post.timestampText,
                        )
                      : PostCard(
                          postId: widget.post.id,
                          imagePaths: widget.post.imagePaths,
                          user: widget.author,
                          caption: widget.post.text,
                          likes: widget.post.likes,
                          views: widget.post.views,
                          timestamp: widget.post.timestampText,
                          musicUrl: widget.post.musicUrl,
                          musicTitle: widget.post.musicTitle,
                          musicArtist: widget.post.musicArtist,
                          musicCoverUrl: widget.post.musicCoverUrl,
                          musicTrimStart: widget.post.musicTrimStart,
                          musicStickerConfig: widget.post.musicStickerConfig,
                          musicVolume: widget.post.musicVolume,
                          originalAudioVolume: widget.post.originalAudioVolume,
                          filterIndex: widget.post.filterIndex,
                          textOverlays: widget.post.textOverlays,
                          drawPaths: widget.post.drawPaths,
                          isVideoPost: widget.post.isVideoPost || widget.post.type == PostType.waves,
                          videoHasSound: widget.post.videoHasSound,
                          coverImagePath: widget.post.coverImagePath,
                          mediaAspectRatio: widget.post.mediaAspectRatio,
                          mediaIsBaked: widget.post.mediaIsBaked,
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
