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
      "id": "kp_official",
      "url": "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
      "username": "knockpost_official",
      "caption": "Building KnockPost — the future of social 🚀",
    },
    {
      "id": "zayn01",
      "url": "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
      "username": "zayn.malik",
      "caption": "Vibing to the new beats 🎤✨ #zayn #music #life",
    },
    {
      "id": "saptarshi01",
      "url": "https://www.w3schools.com/tags/mov_bbb.mp4",
      "username": "saptarshi.nayak",
      "caption": "Finding peace in the heart of nature 🌿🌊 #vibes #naturelover",
    },
    {
      "id": "design_daily",
      "url": "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4",
      "username": "design_daily",
      "caption": "Clean UI is everything ✨ #design #flutter",
    },
    {
      "id": "dev_comm",
      "url": "https://test-videos.co.uk/vids/jellyfish/mp4/h264/360/Jellyfish_360_10s_1MB.mp4",
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
    // Bottom nav total height = 50px (icons) + system nav bar padding
    // ReelItem adds 20px internally for content spacing, so subtract that
    final bottomNavHeight = 40.0 + MediaQuery.of(context).viewPadding.bottom;

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
                  userId: reels[index]["id"]!,
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
                      Colors.black.withOpacity(0.6),
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
                    const Spacer(),
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
