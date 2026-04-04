import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/post_header.dart';
import '../../widgets/reaction_bar.dart';

class ThoughtCard extends StatefulWidget {
  final UserModel user;
  final String text;
  final int likes;
  final int views;

  const ThoughtCard({
    super.key,
    required this.user,
    required this.text,
    this.likes = 0,
    this.views = 0,
  });

  @override
  State<ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<ThoughtCard> {
  bool _doubleTapped = false;
  late int _localLikes;
  bool _hasReacted = false;

  @override
  void initState() {
    super.initState();
    _localLikes = widget.likes;
  }

  void _onDoubleTap() {
    KnockHaptics.impact();
    setState(() {
      _doubleTapped = true;
      if (!_hasReacted) {
        _hasReacted = true;
        _localLikes++;
      }
    });
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  void _handleReactionChange(bool reacted) {
    setState(() {
      if (reacted && !_hasReacted) {
        _hasReacted = true;
        _localLikes++;
      } else if (!reacted && _hasReacted) {
        _hasReacted = false;
        _localLikes--;
      }
    });
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
            onReactionChanged: _handleReactionChange,
          ),
        ),

        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text(
                '$_localLikes Likes',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${widget.views} Views',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
