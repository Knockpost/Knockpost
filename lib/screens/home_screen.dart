import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../utils/haptic_helper.dart';
import '../widgets/post_card.dart';
import '../widgets/custom_bottom_nav.dart';
import 'messages/messages_list_screen.dart';
import 'create_post/create_post_screen.dart';
import 'search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool showFab = true;
  int _currentNavIndex = 0;

  // Demo posts with varying image counts
  final List<List<String>> _demoPostImages = const [
    ["assets/test1.jpg", "assets/test2.jpg", "assets/test3.jpg", "assets/test4.jpg"],
    ["assets/test3.jpg"],
    ["assets/test2.jpg", "assets/test4.jpg", "assets/test1.jpg"],
    ["assets/test4.jpg", "assets/test2.jpg"],
    ["assets/test1.jpg"],
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final goingDown = _scrollController.position.userScrollDirection ==
          ScrollDirection.reverse;
      if (goingDown && showFab) {
        setState(() => showFab = false);
      } else if (!goingDown && !showFab) {
        setState(() => showFab = true);
      }
    });
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
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

      floatingActionButton: (_currentNavIndex == 0 && showFab)
          ? FloatingActionButton(
              backgroundColor: textColor,
              onPressed: () {
                KnockHaptics.tap();
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
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _currentNavIndex,
            children: [
              // 0: HOME FEED
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
                    titleSpacing: 10,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                    ),

                    title: Row(
                      children: [
                        Image.asset(
                          isDark ? "assets/icon(white).png" : "assets/icon(black).png",
                          height: 26,
                          errorBuilder: (context, error, stackTrace) => Image.asset("assets/icon(white).png", height: 26),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "KnockPost",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),

                    actions: [
                      IconButton(
                        icon: Icon(Icons.notifications_none, color: textColor),
                        onPressed: () { KnockHaptics.tap(); },
                      ),
                      IconButton(
                        icon: Icon(Icons.logout, color: textColor),
                        onPressed: () {
                          KnockHaptics.tap();
                          logout(context);
                        },
                      ),
                    ],
                  ),
                ];
              },

              body: ListView.separated(
                padding: EdgeInsets.zero,

                itemCount: _demoPostImages.length,

                separatorBuilder: (context, index) {
                  return Divider(
                    thickness: 6,
                    height: 6,
                    color: isDark ? const Color(0xff121212) : const Color(0xfff0f0f0),
                  );
                },

                itemBuilder: (context, index) {
                  return PostCard(imagePaths: _demoPostImages[index]);
                },
              ),
              ),

              // 1: SEARCH PIPELINE
              const SearchScreen(),

              // 2: REELS / VIDEO PIPELINE
              const Center(child: Text("Reels")),

              // 3: MESSAGES PIPELINE
              const MessagesScreen(),

              // 4: PROFILE PIPELINE
              const Center(child: Text("Profile")),
            ],
          ),
        ),
      ),
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
