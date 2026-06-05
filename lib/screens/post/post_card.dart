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
import '../../services/feed_state_service.dart';
import 'dart:async';
import '../../services/feed_media_pool.dart';

// --- EXPERIMENT INSTRUMENTATION ---
int _vdCallbackCount = 0;
int _vdExecutionTimeMicroseconds = 0;
DateTime _vdLastLogTime = DateTime.now();
bool _vdThrottled = false;
// ----------------------------------

// ─────────────────────────────────────────────────────────────────────────────
// PostCard — Unified post rendering with music sticker overlay
//
// Uses MusicStickerWidget for the music sticker display.
// When mediaIsBaked == true, filters/overlays are already in the image,
// so we skip re-applying them.
// ─────────────────────────────────────────────────────────────────────────────

class PostCard extends StatefulWidget {
  final List<String> imagePaths;
  final List<String>? optimizedImagePaths; // from C1 Phase
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
    this.optimizedImagePaths,
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
  StreamSubscription<bool>? _poolPlayingSub;

  bool get _hasMusic =>
      widget.musicUrl != null && widget.musicUrl!.isNotEmpty && !(widget.isVideoPost && widget.mediaIsBaked);

  @override
  void initState() {
    super.initState();
    if (_hasMusic) {
      if (useNewMediaPool) {
        // Pool architecture: don't initialize player here, just listen to global state
        _poolPlayingSub = FeedMediaPool.instance.audioPlayingStream?.listen((playing) {
          if (!mounted || !_isVisible) return;
          if (FeedMediaPool.instance.currentAudioUrl == widget.musicUrl) {
            setState(() => _isPlaying = playing);
          } else if (_isPlaying) {
            setState(() => _isPlaying = false);
          }
        });
      } else {
        _initAudio();
      }
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
    _poolPlayingSub?.cancel();
    if (!useNewMediaPool) {
      if (_audioPlayer != null) {
        AudioLifecycleManager.instance.unregister(_audioPlayer!);
        _audioPlayer!.stop().whenComplete(() => _audioPlayer!.dispose());
      }
    } else {
      if (_isVisible && _hasMusic) {
        FeedMediaPool.instance.pauseAudio();
      }
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
    if (useNewMediaPool) {
      if (_isPlaying) {
        FeedMediaPool.instance.pauseAudio();
        AudioLifecycleManager.instance.isGlobalMuted = true;
        setState(() => _isPlaying = false);
      } else {
        FeedMediaPool.instance.playAudio(widget.musicUrl!, trimStart: widget.musicTrimStart ?? 0);
        AudioLifecycleManager.instance.isGlobalMuted = false;
        setState(() => _isPlaying = true);
      }
    } else {
      if (_isPlaying) {
        _audioPlayer?.pause();
        AudioLifecycleManager.instance.isGlobalMuted = true;
      } else {
        _audioPlayer?.play();
        AudioLifecycleManager.instance.isGlobalMuted = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key ?? Key('post_${widget.postId}'),
      onVisibilityChanged: (info) {
        final stopwatch = Stopwatch()..start();
        
        // Ensure throttling is applied for experiment
        if (!_vdThrottled) {
          VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 100);
          _vdThrottled = true;
          debugPrint('=== EXPERIMENT: VisibilityDetector Throttled to 100ms ===');
        }

        final visibleFraction = info.visibleFraction;
        final bool isNowVisible = visibleFraction >= 0.5;

        if (_isVisible != isNowVisible) {
          _isVisible = isNowVisible;

          if (mounted) {
            setState(() {});
          }

          if (_isVisible && widget.postId != null && !widget.postId!.startsWith('demo_')) {
            if (!_viewedPosts.contains(widget.postId!)) {
              _viewTimer ??= Timer(const Duration(seconds: 2), () {
                if (mounted && _isVisible) {
                  _viewedPosts.add(widget.postId!);
                  FeedStateService.instance.incrementView(widget.postId!, widget.user.id);
                }
                _viewTimer = null;
              });
            }
          } else {
            // Post is not visible enough — cancel any pending view timer
            _viewTimer?.cancel();
            _viewTimer = null;
          }

          if (_hasMusic) {
            if (useNewMediaPool) {
              if (!_isVisible) {
                if (_isPlaying) {
                  FeedMediaPool.instance.pauseAudio();
                  setState(() => _isPlaying = false);
                }
              } else {
                if (!AudioLifecycleManager.instance.isGlobalMuted) {
                  FeedMediaPool.instance.playAudio(widget.musicUrl!, trimStart: widget.musicTrimStart ?? 0);
                }
              }
            } else {
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
            }
          }
        }
        
        stopwatch.stop();
        _vdCallbackCount++;
        _vdExecutionTimeMicroseconds += stopwatch.elapsedMicroseconds;
        
        final now = DateTime.now();
        if (now.difference(_vdLastLogTime).inSeconds >= 1) {
          debugPrint('=== EXPERIMENT METRICS ===');
          debugPrint('Callbacks per second: $_vdCallbackCount');
          debugPrint('Total callback execution time: ${_vdExecutionTimeMicroseconds / 1000} ms');
          debugPrint('Average time per callback: ${_vdExecutionTimeMicroseconds / (_vdCallbackCount == 0 ? 1 : _vdCallbackCount)} microseconds');
          debugPrint('==========================');
          
          _vdCallbackCount = 0;
          _vdExecutionTimeMicroseconds = 0;
          _vdLastLogTime = now;
        }
      },
      child: RepaintBoundary(
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
            musicTitle: widget.musicTitle,
            musicArtist: widget.musicArtist,
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
        Stack(
          children: [
            MediaCarousel(
              imagePaths: widget.imagePaths,
              optimizedImagePaths: widget.optimizedImagePaths,
              isVideoPost: widget.isVideoPost,
              isBakedVideo: widget.mediaIsBaked,
              onDoubleTap: _onDoubleTap,
              mediaAspectRatio: widget.mediaAspectRatio,
              isVisible: _isVisible, // Pass visibility down to pool
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
            postThumbnailUrl: widget.imagePaths.isNotEmpty
                ? widget.imagePaths.first
                : widget.coverImagePath,
          ),
        ),

        const SizedBox(height: 10),
      ],
    ),
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
