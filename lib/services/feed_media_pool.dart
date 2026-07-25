import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:knockpost/utils/audio_lifecycle_manager.dart';
import 'video_cache_manager.dart';

/// -------------------------------------------------------------------------
/// FEATURE FLAG: Easy Rollback
/// Set this to false to instantly revert to the old (synchronous) architecture
/// -------------------------------------------------------------------------
const bool useNewMediaPool = true;

class FeedMediaPool {
  FeedMediaPool._();
  static final FeedMediaPool instance = FeedMediaPool._();

  // ── Global Audio ──
  AudioPlayer? _globalAudioPlayer;
  String? _currentAudioUrl;
  bool _audioInitialized = false;

  void _initAudioIfNeeded() {
    if (_audioInitialized) return;
    _globalAudioPlayer = AudioPlayer();
    AudioLifecycleManager.instance.register(_globalAudioPlayer!);
    _audioInitialized = true;
  }

  String? get currentAudioUrl => _currentAudioUrl;

  Future<void> playAudio(String url, {int trimStart = 0}) async {
    _initAudioIfNeeded();
    if (AudioLifecycleManager.instance.isGlobalMuted) return;

    if (_currentAudioUrl != url) {
      _currentAudioUrl = url;
      try {
        final uri = Uri.parse(url);
        final source = ClippingAudioSource(
          child: AudioSource.uri(uri),
          start: Duration(seconds: trimStart),
          end: Duration(seconds: trimStart + 15),
        );
        await _globalAudioPlayer!.setAudioSource(source);
        await _globalAudioPlayer!.setLoopMode(LoopMode.one);
      } catch (e) {
        debugPrint('FeedMediaPool Audio error: $e');
      }
    }
    
    try {
      await _globalAudioPlayer!.play();
    } catch (_) {}
  }

  void pauseAudio() {
    if (_globalAudioPlayer?.playing == true) {
      _globalAudioPlayer?.pause();
    }
  }
  
  Stream<bool>? get audioPlayingStream => _globalAudioPlayer?.playingStream;

  // ── Global Video LRU Pool ──
  static const int maxVideoControllers = 5;
  final Map<String, VideoPlayerController> _videoControllers = {};
  final List<String> _videoLru = [];

  Future<VideoPlayerController> getVideoController(
    String path, {
    bool isAsset = false,
    bool isBakedVideo = false,
  }) async {
    // If it already exists in the pool, move to front of LRU and return
    if (_videoControllers.containsKey(path)) {
      _videoLru.remove(path);
      _videoLru.add(path);
      return _videoControllers[path]!;
    }

    // Ensure we don't exceed max capacity
    if (_videoControllers.length >= maxVideoControllers) {
      final oldestPath = _videoLru.removeAt(0);
      final oldestController = _videoControllers.remove(oldestPath);
      oldestController?.dispose();
    }

    // Create new controller — cache-first for network URLs
    VideoPlayerController controller;
    if (path.startsWith('http')) {
      // Check disk cache first for instant playback
      final fileInfo = await KnockpostVideoCacheManager.instance.getFileFromCache(path);
      if (fileInfo != null && await fileInfo.file.exists()) {
        // INSTANT PLAYBACK FROM DISK CACHE!
        controller = VideoPlayerController.file(
          fileInfo.file,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        // Network stream + start background caching
        controller = VideoPlayerController.networkUrl(
          Uri.parse(path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        // Background cache for next time
        KnockpostVideoCacheManager.instance.downloadFile(path);
      }
    } else if (isAsset || path.startsWith('assets/')) {
      controller = VideoPlayerController.asset(
        path,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else {
      controller = VideoPlayerController.file(
        File(path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }

    // Add to pool
    _videoControllers[path] = controller;
    _videoLru.add(path);

    // Initialize asynchronously off the main build thread
    await Future.microtask(() async {
      try {
        await controller.initialize();
        await controller.setVolume(isBakedVideo ? 1.0 : 0.0);
        await controller.setLooping(true);
      } catch (e) {
        debugPrint('FeedMediaPool Video error: $e');
      }
    });

    return controller;
  }

  void pauseAllVideos() {
    for (final controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void disposeAll() {
    if (_globalAudioPlayer != null) {
      AudioLifecycleManager.instance.unregister(_globalAudioPlayer!);
      _globalAudioPlayer!.dispose();
      _globalAudioPlayer = null;
      _audioInitialized = false;
      _currentAudioUrl = null;
    }
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    _videoControllers.clear();
    _videoLru.clear();
  }
}
