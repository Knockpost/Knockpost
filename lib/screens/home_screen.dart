import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/post_card.dart';
import 'create_post/create_post_screen.dart';
import 'messages/messages_list_screen.dart';
import 'profile/profile_screen.dart';
import 'reels/reels_screen.dart';
import 'search/search_screen.dart';

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
  bool showFab = true;
  int _currentNavIndex = 0;

  final List<List<String>> _demoPostImages = const [
    [
      "assets/test1.jpg",
      "assets/test2.jpg",
      "assets/test3.jpg",
      "assets/test4.jpg",
    ],
    ["assets/test3.jpg"],
    ["assets/test2.jpg", "assets/test4.jpg", "assets/test1.jpg"],
    ["assets/test4.jpg", "assets/test2.jpg"],
    ["assets/test1.jpg"],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentNavIndex);
    _navIndexNotifier = ValueNotifier<int>(_currentNavIndex);

    _scrollController.addListener(() {
      final goingDown =
          _scrollController.position.userScrollDirection ==
          ScrollDirection.reverse;

      if (goingDown && showFab) {
        setState(() => showFab = false);
      } else if (!goingDown && !showFab) {
        setState(() => showFab = true);
      }
    });
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
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: (isDark || isReelsTab)
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: bgColor,
      ),
      child: WillPopScope(
        onWillPop: () async {
          if (_currentNavIndex != 0) {
            _animateToTab(0);
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: bgColor,
          floatingActionButton: ValueListenableBuilder<int>(
            valueListenable: _navIndexNotifier,
            builder: (context, currentIndex, _) {
              if (currentIndex != 0 || !showFab) {
                return const SizedBox.shrink();
              }

              return FloatingActionButton(
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
              );
            },
          ),
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
              child: PageView(
                controller: _pageController,
                allowImplicitScrolling: true,
                dragStartBehavior: DragStartBehavior.down,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _setCurrentNavIndex,
                children: [
                  _KeepAlivePage(
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
                      body: ListView.separated(
                        padding: EdgeInsets.zero,
                        controller: _scrollController,
                        itemCount: _demoPostImages.length,
                        separatorBuilder: (context, index) {
                          return Divider(
                            thickness: 6,
                            height: 6,
                            color: isDark
                                ? const Color(0xff121212)
                                : const Color(0xfff0f0f0),
                          );
                        },
                        itemBuilder: (context, index) {
                          return PostCard(imagePaths: _demoPostImages[index]);
                        },
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
                    child: ProfileScreen(
                      user: demoOwnUser,
                      posts: demoOwnPosts,
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: ValueListenableBuilder<int>(
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
