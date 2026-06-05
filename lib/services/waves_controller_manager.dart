import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'video_cache_manager.dart';
import 'performance_service.dart';

/// Centralized manager for Waves video controllers implementing a strict Sliding Window Architecture
/// to prevent memory leaks, initialize stampedes, and ensure smooth infinite scrolling.
class WavesControllerManager extends ChangeNotifier {
  static final WavesControllerManager instance = WavesControllerManager._internal();
  WavesControllerManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _initLocks = {};

  /// Retrieves a controller synchronously if it exists in the active window.
  VideoPlayerController? getControllerIfExists(String url) {
    return _controllers[url];
  }

  /// Updates the sliding window to maintain exactly [currentIndex - 1, currentIndex, currentIndex + 1].
  void updateWindow(int currentIndex, List<String> feedUrls) {
    if (feedUrls.isEmpty) return;

    PerformanceService.instance.incrementControllerWindowUpdates();

    final Set<String> requiredUrls = {};
    for (int i = currentIndex - 1; i <= currentIndex + 1; i++) {
      if (i >= 0 && i < feedUrls.length) {
        requiredUrls.add(feedUrls[i]);
      }
    }

    // 1. Evict controllers outside the window
    final urlsToEvict = _controllers.keys.where((url) => !requiredUrls.contains(url)).toList();
    for (final url in urlsToEvict) {
      _disposeControllerSafely(url);
    }

    // 2. Initialize missing controllers in the window
    for (final url in requiredUrls) {
      _initControllerIfNeeded(url);
    }

    // 3. Pause non-current videos
    final activeUrl = feedUrls[currentIndex];
    pauseAllExcept(activeUrl);

    // 4. Aggressive background sliding window preloading [i+2, i+3, i+4]
    for (int i = currentIndex + 2; i <= currentIndex + 4; i++) {
      if (i >= 0 && i < feedUrls.length) {
        final preloadUrl = feedUrls[i];
        KnockpostVideoCacheManager.instance.downloadFile(preloadUrl);
      }
    }
    
    notifyListeners();
  }

  void _initControllerIfNeeded(String url) async {
    if (_controllers.containsKey(url) || _initLocks.containsKey(url)) return;

    PerformanceService.instance.incrementControllerInitializations();

    final completer = Completer<void>();
    _initLocks[url] = completer.future;

    try {
      final fileInfo = await KnockpostVideoCacheManager.instance.getFileFromCache(url);
      
      // If the controller was evicted while checking cache, abort instantly
      if (!_initLocks.containsKey(url)) return;

      VideoPlayerController controller;
      if (fileInfo != null) {
        // INSTANT PLAYBACK FROM DISK!
        controller = VideoPlayerController.file(fileInfo.file);
      } else {
        // Fallback to network stream, but start background caching simultaneously
        KnockpostVideoCacheManager.instance.downloadFile(url);
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      _controllers[url] = controller;
      PerformanceService.instance.setActiveVideoControllers(_controllers.length);

      await controller.initialize();
      controller.setLooping(true);

      // Final check: if evicted during the async initialization, dispose it immediately
      if (!_initLocks.containsKey(url)) {
        controller.dispose();
        _controllers.remove(url);
      }
    } catch (e) {
      debugPrint("Video init error: $e");
    } finally {
      if (_initLocks[url] == completer.future) {
        _initLocks.remove(url);
      }
      if (!completer.isCompleted) completer.complete();
    }
  }

  void _disposeControllerSafely(String url) {
    final controller = _controllers.remove(url);
    if (controller == null) return;

    PerformanceService.instance.setActiveVideoControllers(_controllers.length);

    // Immediately dispose to free hardware decoders!
    // The .catchError in _initControllerIfNeeded will handle the initialization abort safely.
    _initLocks.remove(url);
    controller.dispose();
    
    PerformanceService.instance.incrementControllerDisposals();
  }

  /// Pauses all controllers except the provided active one
  void pauseAllExcept(String activeUrl) {
    for (var entry in _controllers.entries) {
      if (entry.key != activeUrl && entry.value.value.isPlaying) {
        entry.value.pause();
      }
    }
  }

  void disposeAll() {
    final urls = _controllers.keys.toList();
    for (var url in urls) {
      _disposeControllerSafely(url);
    }
  }
}
