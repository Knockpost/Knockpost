import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
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
    
    notifyListeners();
  }

  void _initControllerIfNeeded(String url) {
    if (_controllers.containsKey(url) || _initLocks.containsKey(url)) return;

    PerformanceService.instance.incrementControllerInitializations();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controllers[url] = controller;
    PerformanceService.instance.setActiveVideoControllers(_controllers.length);

    final initFuture = controller.initialize().then((_) {
      controller.setLooping(true);
      _initLocks.remove(url);
    }).catchError((e) {
      debugPrint("Video init error: $e");
      _initLocks.remove(url);
    });

    _initLocks[url] = initFuture;
  }

  Future<void> _disposeControllerSafely(String url) async {
    final controller = _controllers.remove(url);
    if (controller == null) return;

    PerformanceService.instance.setActiveVideoControllers(_controllers.length);

    // If still initializing, await the lock to prevent PlatformException crash
    if (_initLocks.containsKey(url)) {
      try {
        await _initLocks[url];
      } catch (_) {}
    }

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
