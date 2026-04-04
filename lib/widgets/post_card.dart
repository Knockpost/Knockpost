import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/haptic_helper.dart';
import 'post_header.dart';
import 'media_carousel.dart';
import 'reaction_bar.dart';
import 'package:just_audio/just_audio.dart';

class PostCard extends StatefulWidget {
  final List<String> imagePaths;
  final UserModel user;
  final String caption;
  final int likes;
  final int views;
  final String? postId;

  const PostCard({
    super.key,
    required this.imagePaths,
    required this.user,
    this.caption = '',
    this.likes = 0,
    this.views = 0,
    this.postId,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _doubleTapped = false;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.musicUrl != null && widget.musicUrl!.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      
      final start = widget.musicTrimStart ?? 0;
      final uri = Uri.parse(widget.musicUrl!);
      final source = ClippingAudioSource(
        child: AudioSource.uri(uri),
        start: Duration(seconds: start),
        end: Duration(seconds: start + 15),
      );
      
      _audioPlayer!.setAudioSource(source).then((_) {
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
    setState(() => _doubleTapped = true);
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: PostHeader(
            user: widget.user,
            postId: widget.postId,
          ),
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
            postId: widget.postId ?? 'demo_post_${widget.imagePaths.hashCode}',
            isPostOwner: widget.user.isOwnProfile,
            initialLikes: widget.likes,
            initialViews: widget.views,
            shareUsername: widget.user.username,
            shareCaption: widget.caption,
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
