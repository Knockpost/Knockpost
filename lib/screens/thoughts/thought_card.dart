import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/post_header.dart';
import '../../widgets/reaction_bar.dart';

class ThoughtCard extends StatefulWidget {
  final UserModel user;
  final String text;
  final int likes;
  final int views;
  final String? postId;
  final bool disableProfileNavigation;
  final String? timestamp;
  final String? musicTitle;
  final String? musicArtist;

  const ThoughtCard({
    super.key,
    required this.user,
    required this.text,
    this.likes = 0,
    this.views = 0,
    this.postId,
    this.disableProfileNavigation = false,
    this.timestamp,
    this.musicTitle,
    this.musicArtist,
  });

  @override
  State<ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<ThoughtCard> {
  bool _doubleTapped = false;

  void _onDoubleTap() {
    KnockHaptics.impact();
    setState(() {
      _doubleTapped = true;
    });
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
          child: PostHeader(
            user: widget.user,
            postId: widget.postId,
            disableProfileNavigation: widget.disableProfileNavigation,
            timestamp: widget.timestamp,
            postTypeName: 'Thought',
            musicTitle: widget.musicTitle,
            musicArtist: widget.musicArtist,
          ),
        ),

        const SizedBox(height: 12),

        // Double-tap on the thought text triggers reaction
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Container(
                width: double.infinity,
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  widget.text,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    letterSpacing: -0.1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.85),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ReactionBar(
            doubleTapped: _doubleTapped,
            onDoubleTapHandled: _onDoubleTapHandled,
            postId: widget.postId ?? 'thought_${widget.user.username}_${widget.text.hashCode}',
            isPostOwner: widget.user.isOwnProfile,
            initialLikes: widget.likes,
            initialViews: widget.views,
            postAuthor: widget.user,
            shareUsername: widget.user.username,
            shareCaption: widget.text,
            timestamp: widget.timestamp,
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
