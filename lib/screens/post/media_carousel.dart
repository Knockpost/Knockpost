import 'dart:async';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/post_scroll_lock_scope.dart';
import '../../widgets/zoomable_post_image.dart';
import '../../../services/image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/optimized_image.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> imagePaths;
  final List<String>? optimizedImagePaths; // from C1 Phase
  final bool isVideoPost;
  final VoidCallback? onDoubleTap;
  final double? mediaAspectRatio;

  const MediaCarousel({
    super.key,
    required this.imagePaths,
    this.optimizedImagePaths,
    this.isVideoPost = false,
    this.onDoubleTap,
    this.mediaAspectRatio,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;
  Timer? _hideTimer;
  bool _showIndicator = true;
  bool _isZoomInteractionActive = false;
  int _activeCarouselTouchCount = 0;
  bool _isParentPageSwipeLocked = false;
  PostPageSwipeLockController? _pageSwipeLockController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startHideTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageSwipeLockController = PostPageSwipeLockScope.maybeOf(context);
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
    _unlockParentPageSwipe();
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasMultipleImages => widget.imagePaths.length > 1;

  void _handleZoomInteractionChanged(bool isActive) {
    if (_isZoomInteractionActive == isActive) return;

    setState(() => _isZoomInteractionActive = isActive);
  }

  void _handleCarouselPointerDown(PointerDownEvent event) {
    if (!_hasMultipleImages) return;

    _activeCarouselTouchCount += 1;
    if (_activeCarouselTouchCount == 1) {
      _lockParentPageSwipe();
    }
  }

  void _handleCarouselPointerEnd(PointerEvent event) {
    if (!_hasMultipleImages) return;

    _activeCarouselTouchCount = math.max(0, _activeCarouselTouchCount - 1);
    if (_activeCarouselTouchCount == 0) {
      _unlockParentPageSwipe();
    }
  }

  void _lockParentPageSwipe() {
    if (_isParentPageSwipeLocked) return;
    _isParentPageSwipeLocked = true;
    _pageSwipeLockController?.lock();
  }

  void _unlockParentPageSwipe() {
    if (!_isParentPageSwipeLocked) return;
    _isParentPageSwipeLocked = false;
    _pageSwipeLockController?.unlock();
  }


  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;

    // Single image — no carousel, no indicators
    if (!_hasMultipleImages) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: widget.mediaAspectRatio != null
              ? AspectRatio(
                  aspectRatio: widget.mediaAspectRatio!,
                  child: _buildZoomableImage(
                    widget.imagePaths.first,
                    widget.optimizedImagePaths?.isNotEmpty == true ? widget.optimizedImagePaths!.first : null,
                  ),
                )
              : _buildZoomableImage(
                  widget.imagePaths.first,
                  widget.optimizedImagePaths?.isNotEmpty == true ? widget.optimizedImagePaths!.first : null,
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
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handleCarouselPointerDown,
              onPointerUp: _handleCarouselPointerEnd,
              onPointerCancel: _handleCarouselPointerEnd,
              child: SizedBox(
                width: screenWidth - 12,
                child: AspectRatio(
                  aspectRatio: widget.mediaAspectRatio ?? 1.0,
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
                        physics: _isZoomInteractionActive
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        itemCount: widget.imagePaths.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                          _onScroll(); // ensure timer resets on page snap
                        },
                        itemBuilder: (context, index) {
                          final optimizedUrl = (widget.optimizedImagePaths != null && widget.optimizedImagePaths!.length > index)
                              ? widget.optimizedImagePaths![index]
                              : null;
                          return _buildZoomableImage(widget.imagePaths[index], optimizedUrl);
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
                                  fontWeight: FontWeight.w700,
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

  Widget _buildZoomableImage(String path, [String? optimizedUrl]) {
    return ZoomablePostImage(
      onDoubleTap: widget.onDoubleTap,
      onInteractionChanged: _hasMultipleImages
          ? _handleZoomInteractionChanged
          : null,
      child: _buildImage(path, optimizedUrl),
    );
  }

  Widget _buildImage(String path, [String? optimizedUrl]) {
    final pathLower = path.toLowerCase();
    final isVideo = widget.isVideoPost ||
        pathLower.contains('.mp4') ||
        pathLower.contains('.mov') ||
        pathLower.contains('.mkv') ||
        pathLower.contains('.webm') ||
        pathLower.contains('.avi');

    if (isVideo) {
      return _VideoItem(path: path, isAsset: path.startsWith('assets/'));
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
      );
    } else if (path.startsWith('http')) {
      return OptimizedImage(
        rawUrl: path,
        optimizedUrl: optimizedUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        cacheManager: KnockpostImageCacheManager.instance,
        errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
      );
    }
  }
}

class _VideoItem extends StatefulWidget {
  final String path;
  final bool isAsset;

  const _VideoItem({required this.path, required this.isAsset});

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.path.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else if (widget.isAsset || widget.path.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(
        widget.path,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else {
      _controller = VideoPlayerController.file(
        File(widget.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }

    _controller.initialize().then((_) {
      _controller.setVolume(0);
      _controller.setLooping(true);
      _controller.play();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: GestureDetector(
          onTap: () {
            setState(() {
              if (_controller.value.isPlaying) {
                _controller.pause();
              } else {
                _controller.play();
              }
            });
          },
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
              if (!_controller.value.isPlaying)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
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
            ],
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        color: Colors.black,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: KnockpostLoadingIndicator(),
          ),
        ),
      ),
    );
  }
}
