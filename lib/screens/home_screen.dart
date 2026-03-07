import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../widgets/post_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final ScrollController _scrollController = ScrollController();
  bool showFab = true;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {

      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {

        if (showFab) {
          setState(() {
            showFab = false;
          });
        }

      } else {

        if (!showFab) {
          setState(() {
            showFab = true;
          });
        }

      }

    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        titleSpacing: 10,

        title: Row(
          children: [

            Image.asset(
              "assets/icon(white).png",
              height: 26,
            ),

            const SizedBox(width:6),

            const Text(
              "KnockPost",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize:18,
              ),
            ),

          ],
        ),

        actions: [

          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.black,
            ),
            onPressed: () {},
          )

        ],
      ),

      floatingActionButton: showFab
          ? FloatingActionButton(
              backgroundColor: Colors.black,
              onPressed: () {},
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            )
          : null,

      body: ListView.separated(

        controller: _scrollController,

        itemCount: 5,

        separatorBuilder: (context,index) {

          return const Divider(
            thickness:1,
            color: Color(0xffeeeeee),
          );

        },

        itemBuilder: (context,index) {

          return const PostCard();

        },

      ),

    );
  }
}