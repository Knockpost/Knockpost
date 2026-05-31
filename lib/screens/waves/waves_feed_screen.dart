import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:flutter/services.dart';
import 'wave_item.dart';
import 'waves_camera_screen.dart';
import '../../utils/waves_feed_state.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/current_user_service.dart';
import '../../services/database_service.dart';
import '../../services/waves_feed_manager.dart';
import '../../services/waves_controller_manager.dart';

class WavesFeedScreen extends StatefulWidget {
  final bool isVisible;
  const WavesFeedScreen({super.key, required this.isVisible});

  @override
  State<WavesFeedScreen> createState() => _WavesFeedScreenState();
}

class _WavesFeedScreenState extends State<WavesFeedScreen> {
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

  // The reels list is now managed dynamically via StreamBuilder in the build method.

  @override
  void initState() {
    super.initState();
    _syncSystemUi();
    WavesFeedState.requestedVideoUrl.addListener(_onVideoRequested);
    WavesFeedState.skipToNextWave.addListener(_onSkipRequested);
    
    if (WavesFeedManager.instance.waves.isEmpty) {
      WavesFeedManager.instance.loadInitial();
    }
  }

  @override
  void didUpdateWidget(covariant WavesFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSystemUi();
  }

  void _syncSystemUi() {
    if (widget.isVisible) {
      SystemChrome.setSystemUIOverlayStyle(_reelsOverlayStyle);
    }
  }

  /// Home feed-এ Wave card tap হলে এই function call হয়।
  /// Navigation logic is now handled inside the StreamBuilder 
  /// using WidgetsBinding.instance.addPostFrameCallback.
  void _onVideoRequested() {
    // Intentionally empty, StreamBuilder handles navigation
  }

  void _onSkipRequested() {
    if (WavesFeedState.skipToNextWave.value) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      WavesFeedState.skipToNextWave.value = false;
    }
  }

  @override
  void dispose() {
    WavesFeedState.requestedVideoUrl.removeListener(_onVideoRequested);
    WavesFeedState.skipToNextWave.removeListener(_onSkipRequested);
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
    // CustomBottomNav is 50px tall. WaveItem adds 20px internally.
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
            KnockPostRefreshIndicator(
              onRefresh: () async {
                await WavesFeedManager.instance.refresh();
              },
              child: AnimatedBuilder(
                animation: WavesFeedManager.instance,
                builder: (context, _) {
                  final feedManager = WavesFeedManager.instance;
                  
                  if (feedManager.isLoading && feedManager.waves.isEmpty) {
                    return const Center(
                      child: KnockPostLoadingIndicator(),
                    );
                  }

                  final waves = feedManager.waves;
                  
                  if (waves.isEmpty) {
                    return const Center(
                      child: Text(
                        'No waves yet.\nBe the first to post!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final url = WavesFeedState.requestedVideoUrl.value;
                    if (url != null) {
                      final idx = waves.indexWhere((p) => p.imagePaths.isNotEmpty && p.imagePaths.first == url);
                      if (idx != -1 && _pageController.hasClients && _pageController.page?.round() != idx) {
                        _pageController.jumpToPage(idx);
                        WavesFeedState.requestedVideoUrl.value = null;
                      }
                    }
                  });

                  return PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: waves.length + (feedManager.hasMore ? 1 : 0),
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

                      // Synchronize sliding window of video controllers
                      final feedUrls = waves.map((w) => w.imagePaths.isNotEmpty ? w.imagePaths.first : '').toList();
                      WavesControllerManager.instance.updateWindow(index, feedUrls);

                      // Fetch next batch early
                      if (index >= waves.length - 3) {
                        feedManager.loadMore();
                      }
                    },
                    itemBuilder: (context, index) {
                      if (index == waves.length) {
                        return const Center(child: KnockPostLoadingIndicator());
                      }

                      final post = waves[index];
                      final currentUser = CurrentUserService.instance.currentUser;
                      
                      if (currentUser != null && post.authorId == currentUser.id) {
                        return WaveItem(
                          key: ValueKey(post.id),
                          videoUrl: post.imagePaths.isNotEmpty ? post.imagePaths.first : '',
                          username: currentUser.username,
                          caption: post.text,
                          isActive: index == currentIndex && widget.isVisible,
                          bottomPadding: bottomNavHeight,
                          post: post,
                          author: currentUser,
                        );
                      }

                      UserModel? author = feedManager.authors[post.authorId];
                      
                      if (author != null) {
                        return WaveItem(
                          key: ValueKey(post.id),
                          videoUrl: post.imagePaths.isNotEmpty ? post.imagePaths.first : '',
                          username: author.username,
                          caption: post.text,
                          isActive: index == currentIndex && widget.isVisible,
                          bottomPadding: bottomNavHeight,
                          post: post,
                          author: author,
                        );
                      }

                      return FutureBuilder<Map<String, dynamic>?>(
                        key: ValueKey('future_${post.id}'),
                        future: DatabaseService.instance.getUserProfile(post.authorId, useCache: true),
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          final fetchedAuthor = data != null
                              ? UserModel(
                                  id: post.authorId,
                                  displayName: data['displayName'] ?? data['username'] ?? 'User',
                                  username: data['username'] ?? post.authorId,
                                  avatarAsset: data['profileImageUrl'],
                                )
                              : UserModel(id: post.authorId, displayName: 'Loading...', username: '...');

                          return WaveItem(
                            key: ValueKey(post.id),
                            videoUrl: post.imagePaths.isNotEmpty ? post.imagePaths.first : '',
                            username: fetchedAuthor.username,
                            caption: post.text,
                            isActive: index == currentIndex && widget.isVisible,
                            bottomPadding: bottomNavHeight,
                            post: post,
                            author: fetchedAuthor,
                          );
                        },
                      );
                    },
                  );
                },
              ),
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
                        "Waves",
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
                            builder: (context) => const WavesCameraScreen(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 28,
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
