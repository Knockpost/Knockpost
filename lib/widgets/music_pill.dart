import 'package:flutter/material.dart';

/// A compact, premium "Now Playing" music pill for post card headers.
///
/// Displays a small rounded chip with an animated equalizer icon,
/// song title, and optional artist name. Designed to feel native to
/// KnockPost's privacy-first, clean aesthetic.
class MusicPill extends StatefulWidget {
  final String title;
  final String? artist;
  final VoidCallback? onTap;

  const MusicPill({
    super.key,
    required this.title,
    this.artist,
    this.onTap,
  });

  @override
  State<MusicPill> createState() => _MusicPillState();
}

class _MusicPillState extends State<MusicPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF2A2A2A) // Dark mode button bg
        : const Color(0xfff2f2f2); // Light mode button bg

    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.8);

    final subtextColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);


    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 110),
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Music note emoji ──
              const Text(
                '🎵',
                style: TextStyle(fontSize: 8, height: 1.2),
              ),

              const SizedBox(width: 3),

              // ── Song title + artist with fade mask ──
              Flexible(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white,
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.75, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (widget.artist != null &&
                          widget.artist!.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w400,
                            color: subtextColor,
                            height: 1.2,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            widget.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: subtextColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
