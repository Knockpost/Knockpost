import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/audio_lifecycle_manager.dart';
import '../../widgets/post_header.dart';
import 'media_carousel.dart';
import '../../widgets/reaction_bar.dart';
import '../shared/music_editor_screen.dart';
import 'package:just_audio/just_audio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PostCard — Unified post rendering with proper music mode separation
//
// Mode System:
//   - styleIndex == 0 or null  → Music Sticker mode (chip at bottom)
//   - styleIndex >= 1          → Lyrics Overlay mode (animated lyrics on media)
//
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
  final int? musicStyle;
  final String? musicLyrics;
  final Map<String, dynamic>? musicLyricsConfig;
  final int? musicTrimStart;
  final double? musicOverlayX;
  final double? musicOverlayY;
  final double? musicOverlayScale;
  final double? musicOverlayRotation;
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
    this.musicStyle,
    this.musicLyrics,
    this.musicLyricsConfig,
    this.musicTrimStart,
    this.musicOverlayX,
    this.musicOverlayY,
    this.musicOverlayScale,
    this.musicOverlayRotation,
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
  bool _doubleTapped = false;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  int _audioPositionMs = 0;

  // ── Computed mode ──
  bool get _hasMusic =>
      widget.musicUrl != null && widget.musicUrl!.isNotEmpty;

  /// styleIndex >= 1 means lyrics mode; 0 or null means sticker/chip mode
  bool get _isLyricsMode =>
      _hasMusic && (widget.musicStyle ?? 0) >= 1;

  bool get _isStickerMode =>
      _hasMusic && !_isLyricsMode;

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
      _audioPlayer!.play();

      _audioPlayer!.playingStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });

      _audioPlayer!.positionStream.listen((pos) {
        if (mounted) {
          setState(() => _audioPositionMs = pos.inMilliseconds);
        }
      });
    } catch (e) {
      debugPrint('PostCard audio init error: $e');
    }
  }

  @override
  void dispose() {
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
    } else {
      _audioPlayer?.play();
    }
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
            disableProfileNavigation: widget.disableProfileNavigation,
            timestamp: widget.timestamp,
          ),
        ),

        const SizedBox(height: 12),

        if (widget.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              widget.caption,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),

        const SizedBox(height: 14),

        // ── Media + Overlays ──
        LayoutBuilder(
          builder: (context, constraints) {
            final boxWidth = constraints.maxWidth;
            final boxHeight = widget.mediaAspectRatio != null
                ? boxWidth / widget.mediaAspectRatio!
                : boxWidth * (5 / 4); // default 4:5

            return Stack(
              children: [
                MediaCarousel(
                  imagePaths: widget.imagePaths,
                  isVideoPost: widget.isVideoPost,
                  onDoubleTap: _onDoubleTap,
                ),

                // ── Lyrics overlay (ONLY in lyrics mode, NOT when media is baked) ──
                if (_isLyricsMode && !widget.mediaIsBaked)
                  Positioned(
                    left: widget.musicOverlayX != null
                        ? widget.musicOverlayX! * boxWidth
                        : boxWidth * 0.1,
                    top: widget.musicOverlayY != null
                        ? widget.musicOverlayY! * boxHeight
                        : boxHeight * 0.42,
                    child: Transform.rotate(
                      angle: widget.musicOverlayRotation ?? 0,
                      child: Transform.scale(
                        scale: widget.musicOverlayScale ?? 1.0,
                        child: RepaintBoundary(
                          child: MusicStyleOverlayWidget(
                            styleIndex: widget.musicStyle!,
                            title: widget.musicTitle ?? '',
                            artist: widget.musicArtist ?? '',
                            coverUrl: widget.musicCoverUrl ?? '',
                            lyricsLrc: widget.musicLyrics,
                            lyricsConfigData: widget.musicLyricsConfig,
                            timelinePositionMs: _audioPositionMs,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Music Sticker chip (ONLY in sticker mode) ──
                if (_isStickerMode)
                  Positioned(
                    bottom: 15,
                    left: 15,
                    child: _buildMusicChip(),
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
    );
  }

  // ── Music Chip (Sticker Mode Only) ─────────────────────────────────────
  Widget _buildMusicChip() {
    return GestureDetector(
      onTap: _togglePlayback,
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                widget.musicTitle ?? 'Music',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
