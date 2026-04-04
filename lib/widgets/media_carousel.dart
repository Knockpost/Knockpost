import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'knock_zoomer.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> imagePaths;
  final bool isVideoPost;

  const MediaCarousel({
    super.key,
    required this.imagePaths,
    this.isVideoPost = false,
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

  Widget _buildImage(String path) {
    // Check extension or fallback to explicit flag for videos missing extensions
    final hasVideoExtension = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov') || path.toLowerCase().endsWith('.mkv');
    final isVideo = hasVideoExtension || widget.isVideoPost;
    
    if (path.startsWith('assets/')) {
      if (isVideo) return _VideoItem(path: path, isAsset: true);
      return Image.asset(
        path,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else {
      if (isVideo) return _VideoItem(path: path, isAsset: false);
      return Image.file(
        File(path),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }
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
          child: KnockZoomer(
            imagePath: widget.imagePaths.first,
            fit: BoxFit.cover,
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
              width: screenWidth - 12,
              height: screenWidth - 12, // 1:1 square like Instagram
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
                        return KnockZoomer(
                          imagePath: widget.imagePaths[index],
                          fit: BoxFit.cover,
                        );
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
          children: List.generate(
            widget.imagePaths.length,
            (index) {
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
            },
          ),
        ),
      ],
    );
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
      return Stack(
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
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 24, 
          height: 24, 
          child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)
        )
      ),
    );
  }
}
