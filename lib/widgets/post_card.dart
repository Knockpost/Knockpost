import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/haptic_helper.dart';
import 'post_header.dart';
import 'media_carousel.dart';
import 'reaction_bar.dart';

class PostCard extends StatefulWidget {
  final List<String> imagePaths;
  final UserModel user;
  final String caption;

  const PostCard({
    super.key,
    required this.imagePaths,
    required this.user,
    this.caption = '',
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _doubleTapped = false;

  void _onDoubleTap() {
    KnockHaptics.impact();
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: PostHeader(user: widget.user),
        ),

        const SizedBox(height: 12),

        if (widget.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              widget.caption,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),

        const SizedBox(height: 14),

        // Double-tap on image triggers 👍 reaction
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: MediaCarousel(imagePaths: widget.imagePaths),
        ),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ReactionBar(
            doubleTapped: _doubleTapped,
            onDoubleTapHandled: _onDoubleTapHandled,
            postId: 'demo_post_${widget.imagePaths.length}',
            isPostOwner: false, // Viewer perspective for demo
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
