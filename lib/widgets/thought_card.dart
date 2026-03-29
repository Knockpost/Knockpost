import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/haptic_helper.dart';
import 'post_header.dart';
import 'reaction_bar.dart';

class ThoughtCard extends StatefulWidget {
  final UserModel user;
  final String text;

  const ThoughtCard({
    super.key,
    required this.user,
    required this.text,
  });

  @override
  State<ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<ThoughtCard> {
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

        // Double-tap on the thought text triggers 👍 reaction
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: Container(
            width: double.infinity,
            color: Colors.transparent, // Ensure gesture detector takes entire width
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              widget.text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ReactionBar(
            doubleTapped: _doubleTapped,
            onDoubleTapHandled: _onDoubleTapHandled,
            postId: 'demo_thought_${widget.text.hashCode}',
            isPostOwner: false, // Viewer perspective for demo
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
