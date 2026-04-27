import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/audio_lifecycle_manager.dart';
import '../../widgets/post_header.dart';
import 'media_carousel.dart';
import '../../widgets/reaction_bar.dart';
import 'package:just_audio/just_audio.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../shared/music_editor_screen.dart';
import '../../utils/post_render_utils.dart';

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
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _doubleTapped = false;
  bool _isPlaying = false;
  bool _wasVisible = false;
  int _musicPositionMs = 0;
  StreamSubscription<Duration>? _positionSub;

  // Single global audio player for ALL post cards in the feed!
  static AudioPlayer? _globalPlayer;
  static String? _currentPlayingPostId;
  static bool _isFeedUnmuted = false;
  static String? _loadedPostId;

  bool get _shouldUseFeedMusicControls =>
      !(widget.isVideoPost && widget.mediaIsBaked);

  @override
  void initState() {
    super.initState();
    // Re-verify on init if we are the one currently active in the global player
    _syncPlayingState();

    // We listen to the global player's stream if it exists.
    _globalPlayer?.playingStream.listen((playing) {
      if (mounted) _syncPlayingState();
    });
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      if (_currentPlayingPostId == widget.postId) {
        setState(() => _musicPositionMs = position.inMilliseconds);
      }
    });
  }

  void _syncPlayingState() {
    final isMe =
        _currentPlayingPostId == widget.postId && widget.postId != null;
    final isGlobalPlaying = _globalPlayer?.playing ?? false;
    if (_isPlaying != (isMe && isGlobalPlaying)) {
      setState(() => _isPlaying = isMe && isGlobalPlaying);
    }
  }

  AudioPlayer get _player {
    if (_globalPlayer == null) {
      _globalPlayer = AudioPlayer();
      AudioLifecycleManager.instance.register(_globalPlayer!);
      _globalPlayer!.playingStream.listen((_) {});
    }
    return _globalPlayer!;
  }

  @override
  void deactivate() {
    if (_isPlaying) {
      _player.pause();
      _isPlaying = false;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    // Only pause if this specific post was playing when disposed
    if (_currentPlayingPostId == widget.postId &&
        _globalPlayer?.playing == true) {
      _globalPlayer?.pause();
    }
    super.dispose();
  }

  bool _isAudioInitializing = false;

  Future<void> _playMusic() async {
    if (!_shouldUseFeedMusicControls) return;
    if (_isPlaying || _isAudioInitializing) return;

    if (widget.musicUrl == null ||
        widget.musicUrl!.isEmpty ||
        widget.postId == null) {
      return;
    }

    _isAudioInitializing = true;

    try {
      if (_loadedPostId != widget.postId) {
        final start = widget.musicTrimStart ?? 0;
        final uri = Uri.parse(widget.musicUrl!);
        final source = ClippingAudioSource(
          child: AudioSource.uri(uri),
          start: Duration(seconds: start),
          end: Duration(seconds: start + 15),
        );

        await _player.setAudioSource(source);
        await _player.setLoopMode(LoopMode.one);
        _loadedPostId = widget.postId;
      }

      _currentPlayingPostId = widget.postId;

      if (_wasVisible && mounted && _currentPlayingPostId == widget.postId) {
        if (mounted) setState(() => _isPlaying = true);
        await AudioLifecycleManager.instance.playExclusive(_player);

        // Failsafe: if scrolled away during await playExclusive
        if (!_wasVisible && _currentPlayingPostId == widget.postId) {
          _player.pause();
          if (mounted) setState(() => _isPlaying = false);
        }
      }
    } catch (e) {
      debugPrint('PostCard audio init error: $e');
      if (_loadedPostId == widget.postId) _loadedPostId = null;
      if (mounted) setState(() => _isPlaying = false);
    } finally {
      if (mounted) _isAudioInitializing = false;
    }
  }

  Future<void> _toggleMusic() async {
    if (!_shouldUseFeedMusicControls) return;
    KnockHaptics.tap();

    if (_isPlaying) {
      _isFeedUnmuted = false;
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      _isFeedUnmuted = true;
      await _playMusic();
    }
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
    final hasMusicOverlay =
        widget.musicStyle != null &&
        widget.musicStyle != 0;
    final shouldShowFeedMusicControls = _shouldUseFeedMusicControls;

    return VisibilityDetector(
      key: Key('postcard_${widget.postId ?? hashCode}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          final bool newlyVisible = !_wasVisible;
          if (!_wasVisible) {
            if (mounted) setState(() => _wasVisible = true);
          }

          if ((newlyVisible || !_isPlaying) && !_isAudioInitializing) {
            if (widget.musicUrl != null &&
                widget.musicUrl!.isNotEmpty &&
                shouldShowFeedMusicControls &&
                _isFeedUnmuted) {
              _playMusic();
            }
          }
        } else {
          if (_wasVisible) {
            if (mounted) setState(() => _wasVisible = false);
            if (_currentPlayingPostId == widget.postId) {
              _globalPlayer?.pause();
              if (mounted) setState(() => _isPlaying = false);
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
            child: PostHeader(user: widget.user, postId: widget.postId),
          ),

          const SizedBox(height: 12),

          if (widget.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                widget.caption,
                style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
              ),
            ),

          const SizedBox(height: 14),

          // Double-tap on image triggers 👍 reaction
          Stack(
            children: [
              GestureDetector(
                onDoubleTap: _onDoubleTap,
                child: widget.mediaIsBaked
                    ? MediaCarousel(
                        imagePaths: widget.imagePaths,
                        isVideoPost: widget.isVideoPost,
                        videoHasSound: widget.videoHasSound,
                        coverImagePath: widget.coverImagePath,
                        mediaAspectRatio: widget.mediaAspectRatio,
                        isVisible: _wasVisible,
                      )
                    : PostRenderUtils.applyMediaFilters(
                        MediaCarousel(
                          imagePaths: widget.imagePaths,
                          isVideoPost: widget.isVideoPost,
                          videoHasSound: widget.videoHasSound,
                          coverImagePath: widget.coverImagePath,
                          mediaAspectRatio: widget.mediaAspectRatio,
                          isVisible: _wasVisible,
                          onVideoPositionChanged: (ms) {
                            if (widget.isVideoPost && mounted) {
                              setState(() => _musicPositionMs = ms);
                            }
                          },
                        ),
                        widget.filterIndex ?? 0,
                        widget.isVideoPost,
                      ),
              ),
              if (shouldShowFeedMusicControls &&
                  widget.musicUrl != null &&
                  widget.musicUrl!.isNotEmpty &&
                  (widget.musicStyle == null || widget.musicStyle == 0))
                Positioned(
                  bottom: 15,
                  left: 15,
                  child: GestureDetector(
                    onTap: _toggleMusic,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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

              // MUSIC LYRICS/STICKERS
              if (hasMusicOverlay)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final currentPosMs = _musicPositionMs + ((widget.musicTrimStart ?? 0) * 1000);
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                left: (widget.musicOverlayX ?? 0.1) * constraints.maxWidth,
                                top: (widget.musicOverlayY ?? 0.14) * constraints.maxHeight,
                                child: Transform.scale(
                                  scale: widget.musicOverlayScale ?? 1.0,
                                  alignment: Alignment.center,
                                  child: Transform.rotate(
                                    angle: widget.musicOverlayRotation ?? 0.0,
                                    alignment: Alignment.center,
                                    child: MusicStyleOverlayWidget(
                                      styleIndex: widget.musicStyle!,
                                      title: widget.musicTitle ?? '',
                                      artist: widget.musicArtist ?? '',
                                      coverUrl: widget.musicCoverUrl ?? '',
                                      lyricsLrc: widget.musicLyrics,
                                      lyricsConfigData: widget.musicLyricsConfig,
                                      timelinePositionMs: currentPosMs,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
      ),
    );
  }
}
