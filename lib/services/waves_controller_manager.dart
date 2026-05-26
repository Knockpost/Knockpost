import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Centralized manager for Waves video controllers to prevent memory leaks,
/// optimize preloading, and ensure smooth infinite scrolling.
class WavesControllerManager {
  static final WavesControllerManager instance = WavesControllerManager._internal();
  WavesControllerManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  
  // Maximum active controllers to keep in memory to prevent crashes
  final int _maxCacheSize = 5;
  final List<String> _recentlyUsedUrls = [];

  /// Gets an existing controller or initializes a new one.
  Future<VideoPlayerController> getController(String url) async {
    if (_controllers.containsKey(url)) {
      _makeRecent(url);
      return _controllers[url]!;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    
    // We don't await initialization to avoid blocking the UI thread
    // The VideoPlayer widget will handle the uninitialized state gracefully.
    controller.initialize().then((_) {
      controller.setLooping(true);
    }).catchError((e) {
      debugPrint("Video init error: $e");
    });
    
    _controllers[url] = controller;
    _makeRecent(url);
    _cleanupOldControllers();
    
    return controller;
  }

  /// Preloads a video without playing it (used for next videos in feed)
  void preload(String url) {
    if (!_controllers.containsKey(url)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      controller.initialize().then((_) {
        controller.setLooping(true);
      }).catchError((_) {});
      _controllers[url] = controller;
      _makeRecent(url);
      _cleanupOldControllers();
    }
  }

  /// Pauses all controllers except the provided active one
  void pauseAllExcept(String activeUrl) {
    for (var entry in _controllers.entries) {
      if (entry.key != activeUrl && entry.value.value.isPlaying) {
        entry.value.pause();
      }
    }
  }

  void _makeRecent(String url) {
    _recentlyUsedUrls.remove(url);
    _recentlyUsedUrls.add(url);
  }

  void _cleanupOldControllers() {
    if (_recentlyUsedUrls.length > _maxCacheSize) {
      final oldUrl = _recentlyUsedUrls.removeAt(0);
      final controllerToDispose = _controllers.remove(oldUrl);
      controllerToDispose?.dispose();
    }
  }

  void disposeAll() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _recentlyUsedUrls.clear();
  }
}
