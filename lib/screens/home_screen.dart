import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../widgets/post_card.dart';
import 'messages/messages_screen.dart';
import 'create_post/create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool showFab = true;

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      floatingActionButton: showFab
          ? FloatingActionButton(
              backgroundColor: Colors.black,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,

      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              floating: true,
              snap: true,
              titleSpacing: 10,
              systemOverlayStyle: SystemUiOverlayStyle.dark,

              title: Row(
                children: [
                  Image.asset("assets/icon(white).png", height: 26),
                  const SizedBox(width: 6),
                  const Text(
                    "KnockPost",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),

              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.black),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MessagesScreen()),
                    );
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
            return const Divider(
              thickness: 6,
              height: 6,
              color: Color(0xfff0f0f0),
            );
          },

          itemBuilder: (context, index) {
            return PostCard(imagePaths: _demoPostImages[index]);
          },
        ),
      ),
    );
  }
}
