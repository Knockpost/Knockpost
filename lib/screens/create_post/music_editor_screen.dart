import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'music_picker_screen.dart';

class MusicOverlayScreen extends StatefulWidget {
  final MusicTrack track;
  final bool isVideo;

  const MusicOverlayScreen({
    super.key,
    required this.track,
    this.isVideo = false,
  });

  @override
  State<MusicOverlayScreen> createState() => _MusicOverlayScreenState();
}

class _MusicOverlayScreenState extends State<MusicOverlayScreen> {
  int _selectedStyleIndex = 0; // 0: None, 1: Style 1, 2: Style 2, 3: Style 3
  double _scrollOffset = 0.3; // 0.0 to 1.0 represents the music track position
  int _duration = 15; // 15 seconds max

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8), // Dark transparent overlay mimicking Insta
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP BAR ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // Balance the 'Done' text
                  Row(
                    children: [
                      _topIcon(Icons.feedback_outlined), // Placeholder for lyrics warning/feedback
                      const SizedBox(width: 16),
                      // Album Art box
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          image: const DecorationImage(
                            image: NetworkImage("https://i.pravatar.cc/100"), // Placeholder track art
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Color wheel circle
                      Container(
                        width: 32, height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      KnockHaptics.tap();
                      Navigator.pop(context, widget.track);
                    },
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── MIDDLE ARIA (Lyrics or "Music Only") ───
            Expanded(
              child: Center(
                child: Text(
                  _selectedStyleIndex == 0 ? "Music Only" : "${widget.track.title} \n Lyrics Placeholder...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _selectedStyleIndex == 0 ? 24 : 28,
                    fontWeight: _selectedStyleIndex == 0 ? FontWeight.w500 : FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
                  ),
                ),
              ),
            ),

            // ─── BOTTOM CONTROLS ───
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _topIcon(IconData icon) {
    return Icon(icon, color: Colors.white, size: 28);
  }

  Widget _buildBottomControls() {
    return Container(
      color: const Color(0xFF0A0A1A), // Deep navy blue matching the screenshot base
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Style Selectors ───
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _styleOption(0, Icons.not_interested_rounded),
              _styleOptionText(1, "Aa", FontWeight.normal),
              _styleOptionText(2, "Ai", FontWeight.bold, fontStyle: FontStyle.italic),
              _styleOptionText(3, "Aa", FontWeight.w900, hasUnderline: true),
            ],
          ),
          
          const SizedBox(height: 24),

          // ─── Duration Slider Row ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                // Duration Circle (15s)
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _duration.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Track progress line
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 2,
                        color: Colors.white30,
                      ),
                      // Colored progress
                      Positioned(
                        left: 0,
                        right: MediaQuery.sizeOf(context).width * (1 - _scrollOffset) - 100, // naive calc
                        child: Container(
                          height: 2,
                          color: Colors.pinkAccent,
                        ),
                      ),
                      // Progress handle dots
                      Positioned(
                        left: (MediaQuery.sizeOf(context).width - 120) * _scrollOffset,
                        child: Row(
                          children: [
                            _progressDot(Colors.pinkAccent),
                            const SizedBox(width: 4),
                            _progressDot(Colors.white),
                            const SizedBox(width: 4),
                            _progressDot(Colors.pinkAccent),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Stop/Play button
                Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.stop_rounded, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // ─── Colorful Waveform Scroller ───
          SizedBox(
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fake Waveform background lines
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(40, (index) {
                    return Container(
                      width: 3,
                      height: (index % 3 == 0) ? 20 : (index % 2 == 0 ? 12 : 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),

                // Selected gradient highlight box
                Positioned(
                  child: Container(
                    width: 120, // 15 seconds representation
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [Colors.yellowAccent, Colors.pinkAccent, Colors.purpleAccent],
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(10, (index) {
                          return Container(
                            width: 3,
                            height: (index % 2 == 0) ? 18 : 26,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressDot(Color color) {
    return Container(
      width: 4, height: 4,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _styleOption(int index, IconData icon) {
    final isSelected = _selectedStyleIndex == index;
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        setState(() => _selectedStyleIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.red : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _styleOptionText(int index, String text, FontWeight weight, {FontStyle? fontStyle, bool hasUnderline = false}) {
    final isSelected = _selectedStyleIndex == index;
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        setState(() => _selectedStyleIndex = index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 16,
            fontWeight: weight,
            fontStyle: fontStyle,
            decoration: hasUnderline ? TextDecoration.underline : null,
          ),
        ),
      ),
    );
  }
}
