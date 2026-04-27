import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> imagePaths;
  final bool isVideoPost;
  final bool videoHasSound;
  final String? coverImagePath;
  final double? mediaAspectRatio;
  final bool isVisible;
  final ValueChanged<int>? onVideoPositionChanged;

  const MediaCarousel({
    super.key,
    required this.imagePaths,
    this.isVideoPost = false,
    this.videoHasSound = false,
    this.coverImagePath,
    this.mediaAspectRatio,
    this.isVisible = true,
    this.onVideoPositionChanged,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;
  Timer? _hideTimer;
  bool _showIndicator = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showIndicator = false);
      }
    });
  }

  void _onScroll() {
    if (!_showIndicator && mounted) {
      setState(() => _showIndicator = true);
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasMultipleImages => widget.imagePaths.length > 1;

  double get _effectiveAspectRatio {
    final aspectRatio = widget.mediaAspectRatio;
    if (aspectRatio != null && aspectRatio > 0) {
      return aspectRatio;
    }
    return _hasMultipleImages ? 1.0 : 4 / 5;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double frameAspectRatio = _effectiveAspectRatio;
    final double frameWidth = screenWidth - 12;

    // Single image — use 4:5 standard Instagram portrait crop
    if (!_hasMultipleImages) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: AspectRatio(
          aspectRatio: frameAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildMedia(widget.imagePaths.first),
          ),
        ),
      );
    }

    // ── Multiple images — Instagram-style carousel ──
    return Column(
      children: [
        // Image carousel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: frameWidth,
              height: frameWidth / frameAspectRatio,
              child: Stack(
                children: [
                  // Swipeable pages
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        _onScroll();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.imagePaths.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                        _onScroll(); // ensure timer resets on page snap
                      },
                      itemBuilder: (context, index) {
                        return _buildMedia(widget.imagePaths[index]);
                      },
                    ),
                  ),

                  // Glassmorphic premium chip — top right with fade
                  Positioned(
                    top: 14,
                    right: 14,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showIndicator ? 1.0 : 0.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${_currentPage + 1} of ${widget.imagePaths.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Dot indicators ──
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.imagePaths.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 7 : 5.5,
              height: isActive ? 7 : 5.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
            );
          }),
        ),
      ],
    );
  }

  bool _looksLikeVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  Widget _buildMedia(String path) {
    final parentVisible = widget.isVisible;
    if (widget.isVideoPost || _looksLikeVideo(path)) {
      return _VideoItem(
        path: path, 
        isAsset: path.startsWith('assets/'), 
        hasSound: widget.videoHasSound, 
        coverImagePath: widget.coverImagePath, 
        isVisible: parentVisible,
        onPositionChanged: widget.onVideoPositionChanged,
      );
    }

    Widget img;
    if (path.startsWith('/') ||
        path.startsWith('file://') ||
        path.startsWith('C:') ||
        path.contains('/data/user/')) {
      img = Image.file(
        File(path),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else if (path.startsWith('http')) {
      img = Image.network(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else {
      img = Image.asset(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }

    return img;
  }
}

class _VideoItem extends StatefulWidget {
  final String path;
  final bool isAsset;
  final bool hasSound;
  final String? coverImagePath;
  final bool isVisible;
  final ValueChanged<int>? onPositionChanged;

  const _VideoItem({
    required this.path,
    required this.isAsset,
    required this.hasSound,
    this.coverImagePath,
    required this.isVisible,
    this.onPositionChanged,
  });

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isMuted = true;
  bool _isPlaying = false;
  bool _showPlayIcon = false;
  bool _userPaused = false; // tracks if user manually paused
  

  @override
  void initState() {
    super.initState();
    _controller = widget.isAsset
        ? VideoPlayerController.asset(
            widget.path,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.file(
            File(widget.path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );

    _controller.initialize().then((_) {
      _controller.setVolume(0);
      _controller.setLooping(true);
      if (widget.isVisible) _controller.play();
      if (mounted) {
        setState(() {
          _initialized = true;
          _isPlaying = widget.isVisible;
        });
      }
    });

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (!mounted || !_initialized) return;
    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(_controller.value.position.inMilliseconds);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (!_initialized) return;
      if (widget.isVisible && !_userPaused) {
        _controller.play();
        if (mounted) setState(() => _isPlaying = true);
      } else if (!widget.isVisible) {
        _controller.pause();
        if (mounted) setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_initialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
      _userPaused = true;
      if (mounted) setState(() { _isPlaying = false; _showPlayIcon = true; });
    } else {
      await _controller.play();
      _userPaused = false;
      if (mounted) setState(() { _isPlaying = true; _showPlayIcon = true; });
    }
    // Auto-hide the icon after 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayIcon = false);
    });
  }

  Future<void> _toggleMute() async {
    if (!_initialized || !widget.hasSound) return;
    final nextMuted = !_isMuted;
    await _controller.setVolume(nextMuted ? 0 : 1);
    if (!mounted) return;
    setState(() => _isMuted = nextMuted);
  }

  Widget _buildCoverPlaceholder() {
    final coverPath = widget.coverImagePath;
    if (coverPath == null || coverPath.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.white54, size: 32),
        ),
      );
    }

    if (coverPath.startsWith('assets/')) {
      return Image.asset(coverPath, fit: BoxFit.cover);
    }
    return Image.file(File(coverPath), fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_initialized) {
      content = GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
            // Animated play/pause icon in center
            if (_showPlayIcon)
              Center(
                child: AnimatedOpacity(
                  opacity: _showPlayIcon ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            // Video icon top-left
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam, color: Colors.white, size: 16),
              ),
            ),
            // Paused state: show play button overlay
            if (!_isPlaying)
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
              ),
            // Sound toggle button
            if (widget.hasSound)
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // Still initializing — show clean cover placeholder with no spinner
      content = _buildCoverPlaceholder();
    }

    return content;
  }
}


