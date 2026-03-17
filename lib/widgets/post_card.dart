import 'package:flutter/material.dart';
import 'post_header.dart';
import 'media_carousel.dart';
import 'reaction_bar.dart';

class PostCard extends StatefulWidget {
  final List<String> imagePaths;

  const PostCard({
    super.key,
    required this.imagePaths,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _doubleTapped = false;

  void _onDoubleTap() {
    setState(() => _doubleTapped = true);
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

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

        const SizedBox(height: 10),

        // Double-tap on image triggers 👍 reaction
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: MediaCarousel(imagePaths: widget.imagePaths),
        ),

        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ReactionBar(
            doubleTapped: _doubleTapped,
            onDoubleTapHandled: _onDoubleTapHandled,
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}