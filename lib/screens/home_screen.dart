import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../widgets/post_card.dart';
import '../widgets/custom_bottom_nav.dart';
import 'messages/messages_list_screen.dart';
import 'create_post/create_post_screen.dart';
import 'reels/reels_screen.dart';
import 'search/search_screen.dart'; // ✅ ADD THIS

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,

      /// ➕ FAB (ONLY HOME)
      floatingActionButton: (_currentNavIndex == 0 && showFab)
          ? FloatingActionButton(
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
            )
          : null,

      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: bgColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: bgColor,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _currentNavIndex,
            children: [
              /// 🏠 HOME FEED
              NestedScrollView(
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

              /// 🔍 SEARCH
              const SearchScreen(),

              /// 🎬 REELS (FULLY CONNECTED)
              ReelsScreen(isVisible: _currentNavIndex == 2),

              /// 💬 MESSAGES
              const MessagesScreen(),

              /// 👤 PROFILE
              const Center(child: Text("Profile")),
            ],
          ),
        ),
      ),

      /// 🔻 BOTTOM NAV
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
    );
  }
}
