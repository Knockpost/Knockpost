import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'video_cache_manager.dart';
import 'performance_service.dart';
import 'dart:async';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Centralized manager for Glimpse video controllers implementing a strict Sliding Window Architecture
/// to prevent memory leaks, initialize stampedes, and ensure smooth horizontal scrolling.
class GlimpsControllerManager extends ChangeNotifier {
  static final GlimpsControllerManager instance = GlimpsControllerManager._internal();
  GlimpsControllerManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _initLocks = {};

  /// Retrieves a controller synchronously if it exists in the active window.
  VideoPlayerController? getControllerIfExists(String url) {
    return _controllers[url];
  }

  /// Updates the sliding window to maintain exactly [currentIndex - 1, currentIndex, currentIndex + 1].
  void updateWindow(int currentIndex, List<String> glimpseUrls) {
    if (glimpseUrls.isEmpty) return;

    PerformanceService.instance.incrementGlimpsControllerWindowUpdates();

    final Set<String> requiredUrls = {};
    for (int i = currentIndex - 1; i <= currentIndex + 1; i++) {
      if (i >= 0 && i < glimpseUrls.length) {
        final url = glimpseUrls[i];
        if (url.isNotEmpty) {
          requiredUrls.add(url);
        }
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
    final activeUrl = glimpseUrls[currentIndex];
    pauseAllExcept(activeUrl);

    // 4. Aggressive background sliding window preloading [i+2, i+3, i+4]
    for (int i = currentIndex + 2; i <= currentIndex + 4; i++) {
      if (i >= 0 && i < glimpseUrls.length) {
        final preloadUrl = glimpseUrls[i];
        if (preloadUrl.isNotEmpty) {
          KnockpostVideoCacheManager.instance.downloadFile(preloadUrl);
        }
      }
    }
    
    notifyListeners();
  }

  void _initControllerIfNeeded(String url) async {
    if (_controllers.containsKey(url) || _initLocks.containsKey(url)) return;

    PerformanceService.instance.incrementGlimpsControllerInitializations();

    final completer = Completer<void>();
    _initLocks[url] = completer.future;

    _initializeVideoAsync(url, completer);
  }

  Future<void> _initializeVideoAsync(String url, Completer<void> lockCompleter) async {
    try {
      VideoPlayerController controller;
      
      final fileInfo = await KnockpostVideoCacheManager.instance.getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        controller = VideoPlayerController.file(
          fileInfo.file,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        KnockpostVideoCacheManager.instance.downloadFile(url);
      }

      if (!_initLocks.containsKey(url)) {
        controller.dispose();
        return;
      }

      _controllers[url] = controller;
      PerformanceService.instance.setActiveGlimpsControllers(_controllers.length);

      await controller.initialize();
      controller.setLooping(true);
      
      if (!_initLocks.containsKey(url)) {
        controller.dispose();
        _controllers.remove(url);
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Glimpse Video init error: $e");
    } finally {
      if (_initLocks[url] == lockCompleter.future) {
        _initLocks.remove(url);
      }
      if (!lockCompleter.isCompleted) lockCompleter.complete();
    }
  }

  void _disposeControllerSafely(String url) {
    final controller = _controllers.remove(url);
    if (controller == null) return;

    PerformanceService.instance.setActiveGlimpsControllers(_controllers.length);

    _initLocks.remove(url);
    controller.dispose();
    
    PerformanceService.instance.incrementGlimpsControllerDisposals();
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
    notifyListeners();
  }
}
