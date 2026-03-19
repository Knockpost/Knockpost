import 'package:flutter/material.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> imagePaths;

  const MediaCarousel({
    super.key,
    required this.imagePaths,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasMultipleImages => widget.imagePaths.length > 1;

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) return const SizedBox.shrink();

    final double screenWidth = MediaQuery.of(context).size.width;

    // Single image — no carousel, no indicators
    if (!_hasMultipleImages) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            widget.imagePaths.first,
            width: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
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
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imagePaths.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.asset(
                        widget.imagePaths[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      );
                    },
                  ),

                  // "1/N" counter chip — top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(0, 0, 0, 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${_currentPage + 1}/${widget.imagePaths.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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
                  color: isActive ? Colors.black87 : Colors.grey.shade300,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
