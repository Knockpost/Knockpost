import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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

class _MusicOverlayScreenState extends State<MusicOverlayScreen>
    with SingleTickerProviderStateMixin {
  int _selectedStyleIndex = 0; // 0: Music Only, 1: Aa, 2: Ai, 3: Aa
  int _trimStartSeconds = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late ScrollController _waveformScrollController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveformScrollController = ScrollController()
      ..addListener(() {
        if (_waveformScrollController.hasClients) {
          final offset = _waveformScrollController.offset;
          // Calculate approx seconds
          final secs = (offset / 9.0).clamp(0, 180).toInt();
          if (_trimStartSeconds != secs) {
            setState(() => _trimStartSeconds = secs);
            _audioPlayer.seek(Duration(seconds: secs));
          }
        }
      });

    _playMusicPreview();
  }

  Future<void> _playMusicPreview() async {
    try {
      await _audioPlayer.setUrl(widget.track.previewUrl);
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio error in overlay: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    _waveformScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background shows the photo underneath
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Glassmorphism Backdrop ──
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _glassBtn(
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        onTap: () {
                          KnockHaptics.tap();
                          Navigator.pop(context, null); // Return null on cancel
                        },
                      ),
                      const Text(
                        'SOUND STUDIO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          KnockHaptics.tap();
                          // Return a map containing both track and trim info
                          Navigator.pop(context, {
                            'track': widget.track,
                            'trimStartSeconds': _trimStartSeconds,
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Done",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // ── Hero Album Art (Pulsing Circle) ──
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.05),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                          image: DecorationImage(
                            image: NetworkImage(widget.track.coverUrl),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ── Lyrics Placeholder or "Music Only" ──
                Text(
                  _selectedStyleIndex == 0 ? "Music Only" : "${widget.track.title}\n(Lyrics)",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _selectedStyleIndex == 0 ? 24 : 28,
                    fontWeight: _selectedStyleIndex == 0 ? FontWeight.w600 : FontWeight.w800,
                    letterSpacing: -0.5,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedStyleIndex == 0)
                  Text(
                    widget.track.artist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),

                const Spacer(flex: 3),

                // ── Bottom Panel ──
                Container(
                  padding: const EdgeInsets.only(top: 24, bottom: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Style Selectors
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _styleOption(0, Icons.not_interested_rounded),
                          _styleOptionText(1, "Aa", FontWeight.normal),
                          _styleOptionText(2, "Ai", FontWeight.bold, fontStyle: FontStyle.italic),
                          _styleOptionText(3, "Aa", FontWeight.w900, hasUnderline: true),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Trimmer Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Trim 15s segment',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '0:${_trimStartSeconds.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Futuristic Waveform Scrubber ──
                      Container(
                        height: 90,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Solid White Pill
                            Container(
                              width: 130,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),

                            // Waveform fg
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (Rect bounds) {
                                final screenWidth = MediaQuery.sizeOf(context).width;
                                if (screenWidth <= 0) {
                                  return const LinearGradient(colors: [Colors.transparent, Colors.transparent]).createShader(bounds);
                                }
                                final center = screenWidth / 2;
                                const halfWindow = 65.0; // 130 width / 2
                                final stop1 = ((center - halfWindow) / screenWidth).clamp(0.0, 1.0);
                                final stop2 = ((center + halfWindow) / screenWidth).clamp(0.0, 1.0);

                                return LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.grey.shade400,
                                    Colors.grey.shade400,
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.3),
                                  ],
                                  stops: [0.0, stop1, stop1, stop2, stop2, 1.0],
                                ).createShader(bounds);
                              },
                              child: ListView.builder(
                                controller: _waveformScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: MediaQuery.sizeOf(context).width / 2 - 65,
                                ),
                                itemCount: 150, // Fake track length
                                itemBuilder: (context, i) {
                                  final double height = (i % 5 == 0) ? 32.0 : ((i % 2 == 0) ? 18.0 : 25.0);
                                  return Center(
                                    child: Container(
                                      width: 3.5,
                                      height: height,
                                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            child: Center(child: child),
          ),
        ),
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
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
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
