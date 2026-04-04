import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/post_header.dart';
import 'media_carousel.dart';
import '../../widgets/reaction_bar.dart';
import 'package:just_audio/just_audio.dart';

class PostCard extends StatefulWidget {
  final List<String> imagePaths;
  final UserModel user;
  final String caption;
  final String? musicUrl;
  final String? musicTitle;
  final String? musicArtist;
  final bool isVideoPost;
  final int likes;
  final int views;

  const PostCard({
    super.key,
    required this.imagePaths,
    required this.user,
    this.caption = '',
    this.musicUrl,
    this.musicTitle,
    this.musicArtist,
    this.isVideoPost = false,
    this.likes = 0,
    this.views = 0,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _doubleTapped = false;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  late int _localLikes;
  bool _hasReacted = false;

  @override
  void initState() {
    super.initState();
    _localLikes = widget.likes;
    if (widget.musicUrl != null && widget.musicUrl!.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.setUrl(widget.musicUrl!).then((_) {
        _audioPlayer!.setLoopMode(LoopMode.one);
        _audioPlayer!.play();
      });
      _audioPlayer!.playingStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    KnockHaptics.impact();
    setState(() {
      _doubleTapped = true;
      if (!_hasReacted) {
        _hasReacted = true;
        _localLikes++;
      }
    });
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  void _handleReactionChange(bool reacted) {
    setState(() {
      if (reacted && !_hasReacted) {
        _hasReacted = true;
        _localLikes++;
      } else if (!reacted && _hasReacted) {
        _hasReacted = false;
        _localLikes--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: PostHeader(user: widget.user),
        ),

        const SizedBox(height: 12),

        if (widget.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              widget.caption,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),

        const SizedBox(height: 14),

        // Double-tap on image triggers 👍 reaction
        Stack(
          children: [
            GestureDetector(
              onDoubleTap: _onDoubleTap,
              child: MediaCarousel(
                imagePaths: widget.imagePaths,
                isVideoPost: widget.isVideoPost,
              ),
            ),
            if (widget.musicUrl != null && widget.musicUrl!.isNotEmpty)
              Positioned(
                bottom: 15,
                left: 15,
                child: GestureDetector(
                  onTap: () {
                    KnockHaptics.tap();
                    if (_isPlaying) {
                      _audioPlayer?.pause();
                    } else {
                      _audioPlayer?.play();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPlaying ? Icons.music_note : Icons.music_off,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.musicTitle ?? 'Music',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ReactionBar(
            doubleTapped: _doubleTapped,
            onDoubleTapHandled: _onDoubleTapHandled,
            postId: 'demo_post_${widget.imagePaths.length}',
            isPostOwner: false, // Viewer perspective for demo
            onReactionChanged: _handleReactionChange,
          ),
        ),

        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text(
                '$_localLikes Likes',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${widget.views} Views',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
