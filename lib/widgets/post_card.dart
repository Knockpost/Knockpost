import 'package:flutter/material.dart';
import 'post_header.dart';
import 'media_carousel.dart';
import 'reaction_bar.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: PostHeader(),
        ),

        const SizedBox(height: 8),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            "Found my new favourite line.\n\nThe moment I saw her, a part of me walked out of my body.",
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),

        const SizedBox(height: 12),

        const MediaCarousel(),

        const SizedBox(height: 10),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: ReactionBar(),
        ),

        const SizedBox(height: 18),
      ],
    );
  }
}
