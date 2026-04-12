import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import 'waves_editor_screen.dart';
import 'waves_gallery_sheet.dart';
import '../shared/music_picker_screen.dart';

class WavesCameraScreen extends StatefulWidget {
  const WavesCameraScreen({super.key});

  @override
  State<WavesCameraScreen> createState() => _WavesCameraScreenState();
}

class _WavesCameraScreenState extends State<WavesCameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _ctrl;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  int _camIndex = 0;

  bool _isRecording = false;
  double _recordProgress = 0.0;
  Timer? _timer;

  MusicTrack? _selectedMusic;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<String> _speedOptions = ['.3x', '.5x', '1x', '2x', '3x'];
  int _selectedSpeedIndex = 2; // Default is 1x

  // ── Overlay states ──
  bool _showEffects = false;
  bool _showFilterStrip = false;
  bool _showTagInput = false;
  bool _showMusicTrimmer = false;
  int _selectedFilterIndex = 0;
  final TextEditingController _tagController = TextEditingController();
  final List<String> _taggedPeople = [];

  final List<Map<String, dynamic>> _carouselEffects = [
    {
      'id': 'none',
      'icon': Icons.not_interested_rounded,
      'color': Colors.white,
      'label': 'None',
    },
    {
      'id': 'glow',
      'icon': Icons.auto_fix_high_rounded,
      'color': Colors.white,
      'label': 'Glow',
    },
    {
      'id': 'face',
      'icon': Icons.face_retouching_natural_rounded,
      'color': Colors.white,
      'label': 'Smooth',
    },
    {
      'id': 'vivid',
      'icon': Icons.hdr_strong_rounded,
      'color': Colors.white,
      'label': 'Vivid',
    },
    {
      'id': 'vintage',
      'icon': Icons.camera_roll_rounded,
      'color': Colors.white,
      'label': 'Vintage',
    },
    {
      'id': 'noir',
      'icon': Icons.dark_mode_rounded,
      'color': Colors.white,
      'label': 'Noir',
    },
    {
      'id': 'sparkle',
      'icon': Icons.star_border_rounded,
      'color': Colors.white,
      'label': 'Sparkle',
    },
    {
      'id': 'vhs',
      'icon': Icons.videocam_rounded,
      'color': Colors.white,
      'label': 'VHS',
    },
    {
      'id': 'bw',
      'icon': Icons.tonality_rounded,
      'color': Colors.white,
      'label': 'B&W',
    },
    {
      'id': 'cyber',
      'icon': Icons.memory_rounded,
      'color': Colors.white,
      'label': 'Cyber',
    },
    {
      'id': 'fade',
      'icon': Icons.blur_linear_rounded,
      'color': Colors.white,
      'label': 'Fade',
    },
    {
      'id': 'warm',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.white,
      'label': 'Warm',
    },
    {
      'id': 'cool',
      'icon': Icons.ac_unit_rounded,
      'color': Colors.white,
      'label': 'Cool',
    },
    {
      'id': 'dream',
      'icon': Icons.cloud_rounded,
      'color': Colors.white,
      'label': 'Dream',
    },
    {
      'id': 'pastel',
      'icon': Icons.color_lens_rounded,
      'color': Colors.purpleAccent,
      'label': 'Pastel',
    },
    {
      'id': 'moody',
      'icon': Icons.landscape_rounded,
      'color': Colors.teal,
      'label': 'Moody',
    },
    {
      'id': 'sepia',
      'icon': Icons.history_rounded,
      'color': Colors.brown,
      'label': 'Sepia',
    },
    {
      'id': 'chrome',
      'icon': Icons.camera_rounded,
      'color': Colors.blueGrey,
      'label': 'Chrome',
    },
    {
      'id': 'neon',
      'icon': Icons.lightbulb_rounded,
      'color': Colors.yellowAccent,
      'label': 'Neon',
    },
    {
      'id': 'cinematic',
      'icon': Icons.movie_filter_rounded,
      'color': Colors.greenAccent,
      'label': 'Cinema',
    },
  ];

  final List<Map<String, String>> _filterList = [
    {'name': 'Original', 'hex': '#FFFFFF'},
    {'name': 'Noir', 'hex': '#3A3A3A'},
    {'name': 'Warm', 'hex': '#FFB347'},
    {'name': 'Cool', 'hex': '#6EC6FF'},
    {'name': 'Cyber', 'hex': '#00F5D4'},
    {'name': 'Film', 'hex': '#D4A373'},
    {'name': 'Sepia', 'hex': '#C8A87E'},
  ];
  int _currentCarouselIndex = 0;
  late final PageController _carouselController;

  // Music Trimmer State
  late final ScrollController _waveformScrollController;
  int _trimStartSeconds = 0;

  late AnimationController _pulseAnim;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.22);
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));

    _waveformScrollController = ScrollController()
      ..addListener(() {
        if (_waveformScrollController.hasClients) {
          // Calculate approx seconds (each bar is ~9px wide. 15 secs = 140px width window. ~1 sec = 9.3px)
          final offset = _waveformScrollController.offset;
          final secs = (offset / 9.0).clamp(0, 180).toInt();
          if (_trimStartSeconds != secs) {
            setState(() => _trimStartSeconds = secs);
            if (_showMusicTrimmer && _selectedMusic != null) {
              _audioPlayer.seek(Duration(seconds: secs));
            }
          }
        }
      });

    _initCamera();
  }

  Future<void> _playMusicPreview() async {
    if (_selectedMusic == null) return;
    try {
      await _audioPlayer.setUrl(_selectedMusic!.previewUrl);
      await _audioPlayer.seek(Duration(seconds: _trimStartSeconds));
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _setupController(_cameras[_camIndex]);
    } catch (e) {
      debugPrint('Camera init: $e');
    }
  }

  Future<void> _setupController(CameraDescription cam) async {
    setState(() => _isInitialized = false);
    await _ctrl?.dispose();
    _ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: true);
    try {
      await _ctrl!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Setup: $e');
    }
  }

  void _flipCamera() {
    if (_cameras.length < 2) return;
    KnockHaptics.tap();
    _camIndex = (_camIndex + 1) % _cameras.length;
    _setupController(_cameras[_camIndex]);
  }

  Future<void> _takePhoto() async {
    if (!_isInitialized || _ctrl == null) return;
    KnockHaptics.tap();
    final photo = await _ctrl!.takePicture();
    if (mounted) _goToEditor([File(photo.path)]);
  }

  void _toggleFlash() {
    if (!_isInitialized) return;
    KnockHaptics.tap();
    final off = _ctrl!.value.flashMode == FlashMode.off;
    _ctrl!.setFlashMode(off ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  void _cycleSpeed() {
    KnockHaptics.tap();
    setState(() {
      _selectedSpeedIndex = (_selectedSpeedIndex + 1) % _speedOptions.length;
    });
  }

  Future<void> _startRecording() async {
    if (!_isInitialized || _ctrl == null || _isRecording) return;

    // Auto-close open overlays when starting recording
    if (_showMusicTrimmer ||
        _showEffects ||
        _showFilterStrip ||
        _showTagInput) {
      setState(() {
        _showMusicTrimmer = false;
        _showEffects = false;
        _showFilterStrip = false;
        _showTagInput = false;
      });
    }

    KnockHaptics.tap();
    await _ctrl!.startVideoRecording();

    final limit = _selectedMusic != null ? 15 : 150;
    setState(() {
      _isRecording = true;
      _recordProgress = 0.0;
    });

    if (_selectedMusic != null) {
      _audioPlayer.seek(Duration(seconds: _trimStartSeconds));
      _audioPlayer.play();
    }

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(
        () => _recordProgress = (_recordProgress + 0.1 / limit).clamp(0.0, 1.0),
      );
      if (_recordProgress >= 1.0) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _ctrl == null) return;
    _timer?.cancel();
    _audioPlayer.pause();
    final video = await _ctrl!.stopVideoRecording();
    KnockHaptics.tap();
    setState(() {
      _isRecording = false;
      _recordProgress = 0.0;
    });
    if (mounted) _goToEditor([File(video.path)]);
  }

  void _goToEditor(List<File> files) {
    final speedMultiplier =
        double.tryParse(
          _speedOptions[_selectedSpeedIndex].replaceAll('x', ''),
        ) ??
        1.0;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WavesEditorScreen(
              files: files, 
              playbackSpeed: speedMultiplier,
              initialMusic: _selectedMusic,
              trimStartSeconds: _trimStartSeconds,
            ),
      ),
    );
  }

  void _openGallery() async {
    KnockHaptics.tap();
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Fully controlled by sheet
      builder: (_) => const WavesGallerySheet(),
    );
    if (result != null && result is List<File> && mounted) {
      _goToEditor(result);
    }
  }

  void _pickMusic() async {
    KnockHaptics.tap();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPickerScreen()),
    );
    if (result != null && result is MusicTrack && mounted) {
      setState(() {
        _selectedMusic = result;
        _showMusicTrimmer = true;
      });
      _playMusicPreview();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _timer?.cancel();
    _audioPlayer.dispose();
    _carouselController.dispose();
    _pulseAnim.dispose();
    _tagController.dispose();
    _waveformScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor:
            Colors.black, // Ensures navigation bar area is black
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isInitialized
            ? _buildCamera()
            : const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
      ),
    );
  }

  ColorFilter _getActiveColorFilter() {
    // If a filter strip filter is active, use that
    if (_selectedFilterIndex > 0) {
      switch (_selectedFilterIndex) {
        case 1: // Noir — high contrast greyscale
          return const ColorFilter.matrix(<double>[
            0.5, 0.5, 0.5, 0, -30, // R
            0.5, 0.5, 0.5, 0, -30, // G
            0.5, 0.5, 0.5, 0, -30, // B
            0, 0, 0, 1, 0, // A
          ]);
        case 2: // Warm — golden tones
          return const ColorFilter.matrix(<double>[
            1.2,
            0.1,
            0,
            0,
            15,
            0,
            1.0,
            0,
            0,
            8,
            0,
            0,
            0.8,
            0,
            -10,
            0,
            0,
            0,
            1,
            0,
          ]);
        case 3: // Cool — blue tones
          return const ColorFilter.matrix(<double>[
            0.85,
            0,
            0,
            0,
            -10,
            0,
            0.95,
            0,
            0,
            0,
            0,
            0,
            1.2,
            0,
            20,
            0,
            0,
            0,
            1,
            0,
          ]);
        case 4: // Cyber — teal + magenta
          return const ColorFilter.matrix(<double>[
            0.9,
            0.1,
            0.1,
            0,
            0,
            0.1,
            1.1,
            0.1,
            0,
            10,
            0.1,
            0.1,
            1.3,
            0,
            20,
            0,
            0,
            0,
            1,
            0,
          ]);
        case 5: // Film — muted warm with lifted blacks
          return const ColorFilter.matrix(<double>[
            1.1,
            0.05,
            0,
            0,
            10,
            0,
            1.0,
            0.05,
            0,
            8,
            0,
            0,
            0.9,
            0,
            15,
            0,
            0,
            0,
            1,
            0,
          ]);
        case 6: // Sepia — classic sepia tone
          return const ColorFilter.matrix(<double>[
            0.393,
            0.769,
            0.189,
            0,
            0,
            0.349,
            0.686,
            0.168,
            0,
            0,
            0.272,
            0.534,
            0.131,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]);
      }
    }

    // Carousel effect overrides
    final effectId = _carouselEffects[_currentCarouselIndex]['id'];
    switch (effectId) {
      case 'glow': // Warm glow + slight saturation boost
        return const ColorFilter.matrix(<double>[
          1.15,
          0.05,
          0,
          0,
          12,
          0.05,
          1.1,
          0,
          0,
          8,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'face': // Beauty / soft skin tone boost
        return const ColorFilter.matrix(<double>[
          1.1,
          0.05,
          0.05,
          0,
          10,
          0.05,
          1.05,
          0.05,
          0,
          10,
          0.05,
          0.05,
          1.0,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'sparkle': // High brightness, vibrant
        return const ColorFilter.matrix(<double>[
          1.3,
          0,
          0,
          0,
          20,
          0,
          1.3,
          0,
          0,
          20,
          0,
          0,
          1.3,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'vhs': // Retro VHS: slightly off-color R/B channels + grain feel
        return const ColorFilter.matrix(<double>[
          1.2,
          0,
          0.1,
          0,
          10,
          0,
          0.9,
          0,
          0,
          0,
          0.1,
          0,
          1.1,
          0,
          15,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'bw': // Pure black and white
        return const ColorFilter.matrix(<double>[
          0.33,
          0.59,
          0.11,
          0,
          0,
          0.33,
          0.59,
          0.11,
          0,
          0,
          0.33,
          0.59,
          0.11,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'vivid':
        return const ColorFilter.matrix([
          1.4,
          0,
          0,
          0,
          0,
          0,
          1.4,
          0,
          0,
          0,
          0,
          0,
          1.4,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'vintage':
        return const ColorFilter.matrix([
          0.9,
          0.2,
          0.1,
          0,
          15,
          0.1,
          0.8,
          0.1,
          0,
          10,
          0.1,
          0.1,
          0.7,
          0,
          5,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'noir':
        return const ColorFilter.matrix([
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'cyber':
        return const ColorFilter.matrix([
          1.2,
          0,
          0.5,
          0,
          10,
          0,
          0.8,
          0.5,
          0,
          0,
          0.5,
          0,
          1.2,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'fade':
        return const ColorFilter.matrix([
          1,
          0,
          0,
          0,
          20,
          0,
          1,
          0,
          0,
          20,
          0,
          0,
          1,
          0,
          20,
          0,
          0,
          0,
          0.85,
          0,
        ]);
      case 'warm':
        return const ColorFilter.matrix([
          1.3,
          0,
          0,
          0,
          15,
          0,
          1.1,
          0,
          0,
          5,
          0,
          0,
          0.8,
          0,
          -15,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'cool':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          -10,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1.3,
          0,
          15,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'dream':
        return const ColorFilter.matrix([
          1.1,
          0,
          0.1,
          0,
          20,
          0,
          1.1,
          0.1,
          0,
          10,
          0,
          0,
          1.1,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'pastel':
        return const ColorFilter.matrix([
          0.9,
          0.1,
          0,
          0,
          30,
          0,
          1.0,
          0.1,
          0,
          20,
          0.1,
          0.1,
          1.1,
          0,
          30,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'moody':
        return const ColorFilter.matrix([
          0.8,
          0,
          0,
          0,
          -20,
          0,
          0.85,
          0,
          0,
          -15,
          0,
          0,
          0.9,
          0,
          -5,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'sepia':
        return const ColorFilter.matrix([
          0.39,
          0.77,
          0.19,
          0,
          0,
          0.35,
          0.69,
          0.17,
          0,
          0,
          0.27,
          0.53,
          0.13,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'chrome':
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          10,
          0,
          1.2,
          0,
          0,
          10,
          0,
          0,
          1.2,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'neon':
        return const ColorFilter.matrix([
          1.5,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.5,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'cinematic':
        return const ColorFilter.matrix([
          1.3,
          0.1,
          0,
          0,
          10,
          0,
          1.1,
          0.1,
          0,
          5,
          0,
          0.2,
          1.3,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
      default: // 'none' — identity matrix
        return const ColorFilter.matrix(<double>[
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }

  // ── Instagram-style Music Sticker (Floats during recording/preview) ──
  Widget _buildMusicSticker() {
    return Positioned(
      top: 100, // Safe padding below the top bar
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedMusic!.title} • ${_selectedMusic!.artist}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Knockpost Signature Music Trimmer Overlay ──
  Widget _buildMusicTrimmerOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 30,
            sigmaY: 30,
          ), // Heavy glassmorphism over camera
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Top Header ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _glassBtn(
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          onTap: () {
                            KnockHaptics.tap();
                            setState(() {
                              _showMusicTrimmer = false;
                              _selectedMusic = null;
                            });
                            _audioPlayer.pause();
                          },
                        ),
                        const Text(
                          'SOUND STUDIO',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 40), // Balance
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Hero Album Art (Pulsing Circle) ──
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.05),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.audiotrack_rounded,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Track Details ──
                  Text(
                    _selectedMusic!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedMusic!.artist,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // ── Futuristic Waveform Scrubber ──
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
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
                      Container(
                        height: 90,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // ── Solid White Instagram Pill (Background) ──
                            Container(
                              width: 130, // Authentic width
                              height: 48, // Solid thick pill
                              decoration: BoxDecoration(
                                color: Colors.white, // Solid pure white
                                borderRadius: BorderRadius.circular(
                                  10,
                                ), // Smooth rounded corners
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),

                            // ── Unified ShaderMask Scrolling Audio Waveform (Foreground) ──
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (Rect bounds) {
                                final screenWidth = MediaQuery.sizeOf(
                                  context,
                                ).width;
                                if (screenWidth <= 0) {
                                  return const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                    ],
                                  ).createShader(bounds);
                                }

                                final center = screenWidth / 2;
                                const halfWindow = 65.0; // 130 width / 2

                                final stop1 =
                                    ((center - halfWindow) / screenWidth).clamp(
                                      0.0,
                                      1.0,
                                    );
                                final stop2 =
                                    ((center + halfWindow) / screenWidth).clamp(
                                      0.0,
                                      1.0,
                                    );

                                return LinearGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: 0.3,
                                    ), // Faint white sliding background tracks
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors
                                        .grey
                                        .shade400, // Dark grey static groove line optical illusion
                                    Colors.grey.shade400,
                                    Colors.white.withValues(
                                      alpha: 0.3,
                                    ), // Faint white sliding background tracks
                                    Colors.white.withValues(alpha: 0.3),
                                  ],
                                  stops: [
                                    0.0,
                                    stop1,
                                    stop1, // Hard slice transition
                                    stop2,
                                    stop2, // Hard slice transition
                                    1.0,
                                  ],
                                ).createShader(bounds);
                              },
                              child: ListView.builder(
                                controller: _waveformScrollController,
                                scrollDirection: Axis.horizontal,
                                physics:
                                    const ClampingScrollPhysics(), // Native hard stop
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.sizeOf(context).width / 2 -
                                      65, // Start exactly inside the 130px window
                                ),
                                itemCount: 150, // Fake track length
                                itemBuilder: (context, i) {
                                  // Instagram has highly varied, dynamic audio beat geometry
                                  final double height = (i % 5 == 0)
                                      ? 32.0
                                      : ((i % 2 == 0) ? 18.0 : 25.0);
                                  return Center(
                                    child: Container(
                                      width: 3.5, // Standard thin groove width
                                      height: height,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors
                                            .white, // Overridden entirely by ShaderMask
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

                  // ── Premium Apply Action Pill ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 30,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        KnockHaptics.tap();
                        setState(() => _showMusicTrimmer = false);
                        _audioPlayer.pause();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: Text(
                            'APPLY SOUND',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCamera() {
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTap: () {
        if (_showEffects) setState(() => _showEffects = false);
        if (_showFilterStrip) setState(() => _showFilterStrip = false);
        if (_showTagInput) setState(() => _showTagInput = false);
        if (_showMusicTrimmer) setState(() => _showMusicTrimmer = false);
      },
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.loose,
              children: [
                // ── Full-Screen Camera Preview (Above Bottom Bar) ──
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: size.width,
                      height: size.width * _ctrl!.value.aspectRatio,
                      child: ColorFiltered(
                        colorFilter: _getActiveColorFilter(),
                        child: CameraPreview(_ctrl!),
                      ),
                    ),
                  ),
                ),

                // ── Live color overlay for glow/sparkle/VHS effects ──
                if (_currentCarouselIndex > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        color:
                            (_carouselEffects[_currentCarouselIndex]['color']
                                    as Color)
                                .withValues(alpha: 0.10),
                      ),
                    ),
                  ),

                // ── Top deep gradient ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 220,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Bottom gradient (Behind shutter only) ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 180,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showMusicTrimmer ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.88),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── TOP BAR (Hidden when trimmer is open) ──
                if (!_showMusicTrimmer)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Close button
                          _glassBtn(
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onTap: () => Navigator.pop(context),
                          ),

                          // Right controls group (Removed per user request)
                          const SizedBox(),
                        ],
                      ),
                    ),
                  ),

                // ── Effects picker overlay ──
                if (_showEffects) _buildEffectsOverlay(),

                // ── Filter strip overlay ──
                if (_showFilterStrip) _buildFilterStripOverlay(),

                // ── Tag input overlay ──
                if (_showTagInput) _buildTagInputOverlay(),

                // ── Music Trimmer Overlay ──
                if (_showMusicTrimmer) _buildMusicTrimmerOverlay(),

                // ── Sticker (Title & Artist) Floating while Recording/Preview ──
                if (!_showMusicTrimmer && _selectedMusic != null)
                  _buildMusicSticker(),

                // ── LEFT SIDE TOOL PILLAR (glassmorphism & scrollable) ──
                if (!_showMusicTrimmer)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 120),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 240, // Expanded for wider layout
                          ),
                          width: 58, // Wider pillar as requested
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 0.5,
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Music
                                      _pillarBtn(
                                        Icons.music_note_rounded,
                                        _pickMusic,
                                        active: _selectedMusic != null,
                                      ),
                                      // 2. Effects
                                      _pillarBtn(
                                        Icons.auto_awesome_rounded,
                                        () {
                                          KnockHaptics.tap();
                                          setState(() {
                                            _showEffects = !_showEffects;
                                            _showFilterStrip = false;
                                            _showTagInput = false;
                                          });
                                        },
                                        active: _showEffects,
                                      ),
                                      // 3. Tag
                                      _pillarBtn(
                                        Icons.person_pin_circle_outlined,
                                        () {
                                          KnockHaptics.tap();
                                          setState(() {
                                            _showTagInput = !_showTagInput;
                                            _showEffects = false;
                                            _showFilterStrip = false;
                                          });
                                        },
                                        active: _showTagInput,
                                      ),
                                      // 4. Filters
                                      _pillarBtn(
                                        Icons.auto_fix_high_rounded,
                                        () {
                                          KnockHaptics.tap();
                                          setState(() {
                                            _showFilterStrip =
                                                !_showFilterStrip;
                                            _showEffects = false;
                                            _showTagInput = false;
                                          });
                                        },
                                        active: _showFilterStrip,
                                      ),

                                      // 5. Flash
                                      _pillarBtn(
                                        _ctrl?.value.flashMode ==
                                                FlashMode.torch
                                            ? Icons.flash_on_rounded
                                            : Icons.flash_off_rounded,
                                        _toggleFlash,
                                        active:
                                            _ctrl?.value.flashMode ==
                                            FlashMode.torch,
                                        color: Colors.white,
                                      ),

                                      // 6. Speed (Hidden initially, requires scrolling)
                                      GestureDetector(
                                        onTap: _cycleSpeed,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _speedOptions[_selectedSpeedIndex],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 15s badge when music selected
                                      if (_selectedMusic != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white70,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '15s',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── SHUTTER AREA CONTROLS ──
                if (!_showMusicTrimmer)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _showEffects ? 0.0 : 1.0,
                      child: IgnorePointer(
                        ignoring: _showEffects,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_isRecording)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'TAP  PHOTO  •  HOLD  VIDEO',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ),
                            SizedBox(
                              height: 100,
                              child: PageView.builder(
                                controller: _carouselController,
                                physics: const BouncingScrollPhysics(),
                                onPageChanged: (idx) {
                                  KnockHaptics.tap();
                                  setState(() => _currentCarouselIndex = idx);
                                },
                                itemCount: _carouselEffects.length,
                                itemBuilder: (context, index) {
                                  final isCenter =
                                      index == _currentCarouselIndex;
                                  final effect = _carouselEffects[index];
                                  final isOriginal = effect['id'] == 'none';
                                  return Center(
                                    child: isCenter
                                        ? _buildActiveShutter(
                                            isOriginal,
                                            effect,
                                          )
                                        : _buildInactiveEffectRing(effect),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ], // ── Stack.children end
            ), // ── Stack end
          ), // ── Expanded end
          // ── BOTTOM CONSTANT BLACK STRIP (Column child) ──
          if (!_showMusicTrimmer && !_showEffects)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _openGallery,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                          image: const DecorationImage(
                            image: AssetImage('assets/splash_icon_light.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _glassBtn(
                      onTap: _flipCamera,
                      child: const Icon(
                        Icons.flip_camera_ios_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ], // Column.children end
      ), // Column end
    ); // GestureDetector return
  } // _buildCamera end

  // ── Helpers ───────────────────────────────────────────────

  Widget _glassBtn({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.25),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _pillarBtn(
    IconData icon,
    VoidCallback onTap, {
    bool active = false,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Icon(
          icon,
          color: active ? color : Colors.white.withValues(alpha: 0.85),
          size: 26,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
        ),
      ),
    );
  }

  // ── Shutter & Carousel Item Builders ──
  Widget _buildActiveShutter(bool isOriginal, Map<String, dynamic> effect) {
    return GestureDetector(
      onTap: _takePhoto,
      onLongPress: _startRecording,
      onLongPressUp: _stopRecording,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            if (!_isRecording && isOriginal)
              ScaleTransition(
                scale: _pulseScale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 3.5,
                    ),
                  ),
                ),
              ),
            if (!_isRecording && !isOriginal)
              // Clean white outline for selected effect
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 3,
                  ),
                ),
              ),

            if (_isRecording)
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: _recordProgress,
                  color: Colors.redAccent,
                  backgroundColor: Colors.white24,
                  strokeWidth: 4,
                ),
              ),

            // Outer black ring (if original) or color ring (if effect)
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOriginal ? Colors.black : Colors.black87,
              ),
            ),

            // Inner fill or icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isRecording ? 36 : 62,
              height: _isRecording ? 36 : 62,
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.redAccent
                    : (isOriginal ? Colors.white : Colors.white12),
                shape: isOriginal || _isRecording
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: isOriginal || _isRecording
                    ? null
                    : BorderRadius.circular(16),
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: (!isOriginal && !_isRecording)
                  ? Icon(effect['icon'], color: Colors.white, size: 32)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveEffectRing(Map<String, dynamic> effect) {
    if (effect['id'] == 'none') {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54, width: 2),
        ),
        child: const Center(
          child: Icon(
            Icons.not_interested_rounded,
            color: Colors.white54,
            size: 22,
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(effect['icon'], color: Colors.white54, size: 24),
      ),
    );
  }

  // ── Instagram-Style Full Bottom Effects Picker (Knockpost Native Style) ──
  Widget _buildEffectsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: MediaQuery.sizeOf(context).height * 0.52, // 52% of screen height
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 300) {
            setState(() => _showEffects = false);
          }
        },
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Colors.black.withValues(alpha: 0.75), // Deep glassmorphism
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Top Bar (Icons + Tabs) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 20),
                        const Icon(
                          Icons.bookmark_border_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 20),
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 24),
                        // Scrollable Tabs
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildTabItem('TRENDING', true),
                                _buildTabItem('CREATIVE', false),
                                _buildTabItem('APPEARANCE', false),
                                _buildTabItem('REELS', false),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Separator Line
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                    margin: const EdgeInsets.only(bottom: 16),
                  ),

                  // ── Premium Effects Grid ──
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.9,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _carouselEffects.length,
                      itemBuilder: (context, i) {
                        final isActive = _currentCarouselIndex == i;
                        final effect = _carouselEffects[i];
                        final effectIcon = effect['icon'] as IconData;

                        return GestureDetector(
                          onTap: () {
                            KnockHaptics.tap();
                            _carouselController.jumpToPage(i);
                            setState(() {
                              _currentCarouselIndex = i;
                              _showEffects = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Circular icon
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    effectIcon,
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white60,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Effect label
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    effect['label'] as String,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 10,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 6),
            Container(height: 2, width: 24, color: Colors.white),
          ] else ...[
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Filter Strip Overlay (horizontal swatches) ────────────
  Widget _buildFilterStripOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 60, top: 240),
        child: Align(
          alignment: Alignment.topLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Filter',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 68,
                      width: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filterList.length,
                        itemBuilder: (_, i) {
                          final isActive = _selectedFilterIndex == i;
                          final hex = _filterList[i]['hex']!.replaceAll(
                            '#',
                            '',
                          );
                          final color = Color(int.parse('FF$hex', radix: 16));
                          return GestureDetector(
                            onTap: () {
                              KnockHaptics.tap();
                              setState(() => _selectedFilterIndex = i);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color,
                                      border: Border.all(
                                        color: isActive
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(
                                                  alpha: 0.6,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : [],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _filterList[i]['name']!,
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 9,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tag People Overlay ────────────────────────────────────
  Widget _buildTagInputOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 60, top: 160),
        child: Align(
          alignment: Alignment.topLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tag People',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.alternate_email_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Username...',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                setState(() {
                                  _taggedPeople.add('@${val.trim()}');
                                  _tagController.clear();
                                });
                                KnockHaptics.tap();
                              }
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final val = _tagController.text.trim();
                            if (val.isNotEmpty) {
                              setState(() {
                                _taggedPeople.add('@$val');
                                _tagController.clear();
                              });
                              KnockHaptics.tap();
                            }
                          },
                          child: const Icon(
                            Icons.add_circle_rounded,
                            color: Colors.white70,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    if (_taggedPeople.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _taggedPeople
                            .map(
                              (tag) => GestureDetector(
                                onTap: () =>
                                    setState(() => _taggedPeople.remove(tag)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
