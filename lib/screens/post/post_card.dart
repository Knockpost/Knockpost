import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/audio_lifecycle_manager.dart';
import '../../widgets/post_header.dart';
import 'media_carousel.dart';
import '../../widgets/reaction_bar.dart';
import '../shared/music_editor_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/post_service.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// PostCard — Unified post rendering with music sticker overlay
//
// Uses MusicStickerWidget for the music sticker display.
// When mediaIsBaked == true, filters/overlays are already in the image,
// so we skip re-applying them.
// ─────────────────────────────────────────────────────────────────────────────

class PostCard extends StatefulWidget {
  final List<String> imagePaths;
  final UserModel user;
  final String caption;
  final int likes;
  final int views;
  final String? postId;
  final String? musicUrl;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicCoverUrl;
  final Map<String, dynamic>? musicStickerConfig;
  final int? musicTrimStart;
  final double? musicVolume;
  final double? originalAudioVolume;
  final int? filterIndex;
  final List<Map<String, dynamic>>? textOverlays;
  final List<Map<String, dynamic>>? drawPaths;
  final bool isVideoPost;
  final bool videoHasSound;
  final String? coverImagePath;
  final double? mediaAspectRatio;
  final bool mediaIsBaked;
  final bool disableProfileNavigation;
  final String? timestamp;

  const PostCard({
    super.key,
    required this.imagePaths,
    required this.user,
    this.caption = '',
    this.likes = 0,
    this.views = 0,
    this.postId,
    this.musicUrl,
    this.musicTitle,
    this.musicArtist,
    this.musicCoverUrl,
    this.musicStickerConfig,
    this.musicTrimStart,
    this.musicVolume,
    this.originalAudioVolume,
    this.filterIndex,
    this.textOverlays,
    this.drawPaths,
    this.isVideoPost = false,
    this.videoHasSound = false,
    this.coverImagePath,
    this.mediaAspectRatio,
    this.mediaIsBaked = false,
    this.disableProfileNavigation = false,
    this.timestamp,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static final Set<String> _viewedPosts = {};
  bool _doubleTapped = false;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isVisible = false;
  Timer? _viewTimer;

  bool get _hasMusic =>
      widget.musicUrl != null && widget.musicUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasMusic) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();
    AudioLifecycleManager.instance.register(_audioPlayer!);

    try {
      final start = widget.musicTrimStart ?? 0;
      final uri = Uri.parse(widget.musicUrl!);
      final source = ClippingAudioSource(
        child: AudioSource.uri(uri),
        start: Duration(seconds: start),
        end: Duration(seconds: start + 15),
      );

      await _audioPlayer!.setAudioSource(source);
      _audioPlayer!.setLoopMode(LoopMode.one);
      
      if (_isVisible && !AudioLifecycleManager.instance.isGlobalMuted) {
        _audioPlayer!.play();
      }

      _audioPlayer!.playingStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
    } catch (e) {
      debugPrint('PostCard audio init error: $e');
    }
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    if (_audioPlayer != null) {
      AudioLifecycleManager.instance.unregister(_audioPlayer!);
      _audioPlayer!.stop().whenComplete(() => _audioPlayer!.dispose());
    }
    super.dispose();
  }

  void _onDoubleTap() {
    KnockHaptics.impact();
    setState(() {
      _doubleTapped = true;
    });
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  void _togglePlayback() {
    KnockHaptics.tap();
    if (_isPlaying) {
      _audioPlayer?.pause();
      AudioLifecycleManager.instance.isGlobalMuted = true;
    } else {
      _audioPlayer?.play();
      AudioLifecycleManager.instance.isGlobalMuted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('post_card_${widget.postId ?? widget.hashCode}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visibleFraction = info.visibleFraction;
        _isVisible = visibleFraction >= 0.5;

        if (_isVisible && widget.postId != null && !widget.postId!.startsWith('demo_')) {
          if (!_viewedPosts.contains(widget.postId!)) {
            _viewTimer ??= Timer(const Duration(seconds: 2), () {
              if (mounted && _isVisible) {
                _viewedPosts.add(widget.postId!);
                PostService.instance.incrementViewCount(widget.postId!, widget.user.id);
              }
            });
          }
        } else {
          _viewTimer?.cancel();
          _viewTimer = null;
        }

        if (_audioPlayer != null) {
          if (!_isVisible) {
            if (_isPlaying) {
              _audioPlayer?.pause();
            }
          } else {
            if (!AudioLifecycleManager.instance.isGlobalMuted) {
              _audioPlayer?.play();
            }
          }
        }
      },
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: PostHeader(
            user: widget.user,
            postId: widget.postId,
            disableProfileNavigation: widget.disableProfileNavigation,
            timestamp: widget.timestamp,
          ),
        ),

        SizedBox(height: widget.caption.isNotEmpty ? 12 : 8),

        if (widget.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              widget.caption,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),

        SizedBox(height: widget.caption.isNotEmpty ? 14 : 4),

        // ── Media + Overlays ──
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                MediaCarousel(
                  imagePaths: widget.imagePaths,
                  isVideoPost: widget.isVideoPost,
                  onDoubleTap: _onDoubleTap,
                  mediaAspectRatio: widget.mediaAspectRatio,
                ),

                // ── Music overlay (handled by MusicStickerWidget) ──
                if (_hasMusic && widget.musicStickerConfig != null && !widget.mediaIsBaked)
                  RepaintBoundary(
                    child: MusicStickerWidget(
                      title: widget.musicTitle ?? '',
                      artist: widget.musicArtist ?? '',
                      coverUrl: widget.musicCoverUrl ?? '',
                      configData: widget.musicStickerConfig,
                      isPlaying: _isPlaying,
                    ),
                  ),

                if (_hasMusic)
                  Positioned(
                    bottom: 15,
                    right: 15,
                    child: _buildCompactMusicButton(),
                  ),
              ],
            );
          },
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
            postAuthor: widget.user,
            shareUsername: widget.user.username,
            shareCaption: widget.caption,
            timestamp: widget.timestamp,
          ),
        ),

        const SizedBox(height: 10),
      ],
    ),
    );
  }

  // ── Compact Music Button ─────────────────────────────────────────────────
  Widget _buildCompactMusicButton() {
    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Icon(
          _isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
