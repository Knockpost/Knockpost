import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
// ignore: unnecessary_import
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/people_suggestion_strip.dart';
import '../widgets/post_card.dart';
import '../widgets/thought_card.dart';
import 'create_post/create_post_screen.dart';
import 'messages/messages_list_screen.dart';
import 'profile/profile_screen.dart';
import 'reels/reels_screen.dart';
import 'search/search_screen.dart';
import '../widgets/system_nav_bar_fill.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PageController _pageController;
  late final ValueNotifier<int> _navIndexNotifier;
  double _horizontalDragDistance = 0;
  double _scrollDelta = 0;
  bool _showBars = true;
  int _currentNavIndex = 0;

  /// Each feed post: the user who posted, their images, and a caption.
  final List<({UserModel user, List<String> images, String caption})>
      _demoFeedPosts = const [
    (
      user: demoZaynMalik,
      images: [
        'assets/test1.jpg',
        'assets/test2.jpg',
        'assets/test3.jpg',
        'assets/test4.jpg',
      ],
      caption:
          'Found my new favourite line.\n\nThe moment I saw her, a part of me walked out of my body.',
    ),
    (
      user: demoSaptarshiNayak,
      images: [],
      caption: 'Sometimes you just have to log off and step outside. Life is beautiful when you actually look at it without a screen in the way. 🍃✨',
    ),
    (
      user: demoSaptarshiNayak,
      images: ['assets/test3.jpg'],
      caption: 'Morning run hits different 🏃',
    ),
    (
      user: demoAryaLayek,
      images: ['assets/test2.jpg', 'assets/test4.jpg', 'assets/test1.jpg'],
      caption: 'A weekend well spent ✨',
    ),
    (
      user: demoJustinBieber,
      images: ['assets/test4.jpg', 'assets/test2.jpg'],
      caption: 'Golden hour was different today 🌅',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentNavIndex);
    _navIndexNotifier = ValueNotifier<int>(_currentNavIndex);
  }

  @override
  void dispose() {
    _navIndexNotifier.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setCurrentNavIndex(int index) {
    if (_currentNavIndex == index) return;
    setState(() {
      _currentNavIndex = index;
      // Always show bars when switching tabs — only vertical scroll should hide them
      _showBars = true;
      _scrollDelta = 0;
    });
    _navIndexNotifier.value = index;
  }

  void _animateToTab(int index) {
    if (index < 0 || index > 4 || _currentNavIndex == index) return;

    _setCurrentNavIndex(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _handleHorizontalSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final hasStrongFling = velocity.abs() > 550;
    final hasCommittedDrag = _horizontalDragDistance.abs() > 72;

    if (!hasStrongFling && !hasCommittedDrag) {
      _horizontalDragDistance = 0;
      return;
    }

    if (velocity < 0 || _horizontalDragDistance < 0) {
      _animateToTab(_currentNavIndex + 1);
    } else if (velocity > 0 || _horizontalDragDistance > 0) {
      _animateToTab(_currentNavIndex - 1);
    }

    _horizontalDragDistance = 0;
  }

  /// Handle scroll notifications from the feed (Twitter/X behavior)
  /// Hides bars after scrolling down ~50px, shows immediately on scroll up.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final dy = notification.scrollDelta ?? 0;
      if (dy > 0) {
        // Scrolling down — accumulate distance
        _scrollDelta += dy;
        if (_scrollDelta > 50 && _showBars) {
          setState(() => _showBars = false);
        }
      } else if (dy < 0) {
        // Scrolling up — show immediately
        _scrollDelta = 0;
        if (!_showBars) {
          setState(() => _showBars = true);
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReelsTab = _currentNavIndex == 2;
    final isProfileTab = _currentNavIndex == 4;
    final bgColor = isReelsTab
        ? Colors.black
        : (isDark ? Colors.black : Colors.white);
    final textColor = isReelsTab
        ? Colors.white
        : (isDark ? Colors.white : Colors.black);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isReelsTab
            ? Colors.black
            : (isProfileTab ? Colors.transparent : bgColor),
        statusBarIconBrightness: (isDark || isReelsTab)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: (isDark || isReelsTab)
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: isReelsTab ? Colors.black : bgColor,
        systemNavigationBarIconBrightness: (isDark || isReelsTab)
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: PopScope(
        canPop: _currentNavIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentNavIndex != 0) {
            _animateToTab(0);
          }
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: bgColor,
              // extendBody makes the body render BEHIND the bottomNavigationBar
              // so when nav slides away, content is already there — no white gap!
              extendBody: true,

              // ── FAB (X/Twitter-style fade + scale) ──────────────────
              floatingActionButton: (_currentNavIndex == 0 || _currentNavIndex == 4)
                  ? AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      opacity: _showBars ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        scale: _showBars ? 1.0 : 0.0,
                        child: FloatingActionButton(
                          backgroundColor: textColor,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreatePostScreen(),
                              ),
                            );
                          },
                          child: Icon(Icons.add, color: bgColor),
                        ),
                      ),
                    )
                  : null,

              // ── BODY ────────────────────────────────────────────────────
              body: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  _horizontalDragDistance = 0;
                },
                onHorizontalDragUpdate: (details) {
                  _horizontalDragDistance += details.delta.dx;
                },
                onHorizontalDragEnd: _handleHorizontalSwipeEnd,
                child: SafeArea(
                  top: !(isReelsTab || isProfileTab),
                  bottom: false,
                  child: PageView(
                    controller: _pageController,
                    allowImplicitScrolling: true,
                    dragStartBehavior: DragStartBehavior.down,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _setCurrentNavIndex,
                    children: [
                      _KeepAlivePage(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: NestedScrollView(
                            controller: _scrollController,
                            headerSliverBuilder: (context, innerBoxIsScrolled) {
                              return [
                                SliverAppBar(
                                  backgroundColor: bgColor,
                                  surfaceTintColor: bgColor,
                                  elevation: 0,
                                  floating: true,
                                  snap: true,
                                  titleSpacing: 20,
                                  centerTitle: false,
                                  systemOverlayStyle: SystemUiOverlayStyle(
                                    statusBarIconBrightness: isDark
                                        ? Brightness.light
                                        : Brightness.dark,
                                    statusBarBrightness: isDark
                                        ? Brightness.dark
                                        : Brightness.light,
                                  ),
                                  title: Text(
                                    "KnockPost",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 21,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  actions: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.notifications_none,
                                        color: textColor,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ];
                            },
                            body: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 90),
                              itemCount: _demoFeedPosts.length + 1,
                              itemBuilder: (context, index) {
                                const stripIndex = 2;
                                final totalItems = _demoFeedPosts.length + 1;
                                final isLast = index == totalItems - 1;
                                final dividerColor = isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFE8E8E8);
                                final divider = Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: dividerColor,
                                );

                                Widget content;
                                if (index == stripIndex) {
                                  content = const PeopleSuggestionStrip();
                                } else {
                                  final postIndex = index < stripIndex
                                      ? index
                                      : index - 1;
                                  final post = _demoFeedPosts[postIndex];

                                  if (post.images.isEmpty) {
                                    content = ThoughtCard(
                                      user: post.user,
                                      text: post.caption,
                                    );
                                  } else {
                                    content = PostCard(
                                      imagePaths: post.images,
                                      user: post.user,
                                      caption: post.caption,
                                    );
                                  }
                                }

                                return Column(
                                  children: [
                                    divider,
                                    content,
                                    if (isLast) divider,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const _KeepAlivePage(child: SearchScreen()),
                      ValueListenableBuilder<int>(
                        valueListenable: _navIndexNotifier,
                        builder: (context, currentIndex, _) {
                          return _KeepAlivePage(
                            child: ReelsScreen(isVisible: currentIndex == 2),
                          );
                        },
                      ),
                      const _KeepAlivePage(child: MessagesScreen()),
                      _KeepAlivePage(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: ProfileScreen(
                            user: demoOwnUser,
                            posts: demoOwnPosts,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── BOTTOM NAV BAR ──────────────────────────────────────────
              // ClipRect ensures the nav is clipped as it slides out of view
              bottomNavigationBar: ClipRect(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  offset: _showBars ? Offset.zero : const Offset(0, 1),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _navIndexNotifier,
                    builder: (context, currentIndex, _) {
                      return CustomBottomNav(
                        currentIndex: currentIndex,
                        onTap: (index) {
                          if (currentIndex == index) return;
                          _animateToTab(index);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── SOLID BAR BEHIND SYSTEM NAVIGATION BAR ──────────────────
            // On Android 15+ the system nav bar is always transparent.
            // This draws a solid color behind it so it looks opaque.
            SystemNavBarFill(color: bgColor),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
