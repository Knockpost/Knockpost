import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reel_item.dart';
import '../create_post/create_post_screen.dart';

class ReelsScreen extends StatefulWidget {
  final bool isVisible;
  const ReelsScreen({super.key, required this.isVisible});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  int currentIndex = 0;
  static const SystemUiOverlayStyle _reelsOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  final List<Map<String, String>> reels = [
    {
      "url":
          "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
      "username": "knockpost_official",
      "caption": "Building KnockPost — the future of social 🚀",
    },
    {
      "url":
          "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
      "username": "design_daily",
      "caption": "Clean UI is everything ✨ #design #flutter",
    },
    {
      "url":
          "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
      "username": "dev_community",
      "caption": "Drop a 🔥 if you love Flutter!",
    },
  ];

  @override
  void initState() {
    super.initState();
    _syncSystemUi();
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSystemUi();
  }

  void _syncSystemUi() {
    if (widget.isVisible) {
      SystemChrome.setSystemUIOverlayStyle(_reelsOverlayStyle);
    }
  }

  @override
  void dispose() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: isDark ? Colors.black : Colors.white,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
    );
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CustomBottomNav is 50px tall. ReelItem adds 20px internally.
    // 30.0 + 20.0 = 50.0. This makes the text flush with the top of the nav bar, eliminating the gap.
    final bottomNavHeight = 30.0 + MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _reelsOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            /// 🎬 REEL PAGES (vertical scroll)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: reels.length,
              pageSnapping: true,
              physics: const _FastReelsPagePhysics(
                parent: BouncingScrollPhysics(
                  decelerationRate: ScrollDecelerationRate.fast,
                ),
              ),
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return ReelItem(
                  videoUrl: reels[index]["url"]!,
                  username: reels[index]["username"]!,
                  caption: reels[index]["caption"]!,
                  isActive: index == currentIndex && widget.isVisible,
                  bottomPadding: bottomNavHeight,
                );
              },
            ),

            /// 🔝 TOP HEADER
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ignore: prefer_const_constructors
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: const Text(
                        "Glimpse",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreatePostScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FastReelsPagePhysics extends PageScrollPhysics {
  const _FastReelsPagePhysics({super.parent});

  @override
  _FastReelsPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _FastReelsPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.7, stiffness: 220.0, damping: 26.0);

  @override
  double get minFlingVelocity => 260.0;

  @override
  double get maxFlingVelocity => 9000.0;
}
