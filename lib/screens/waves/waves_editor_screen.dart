import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/audio_lifecycle_manager.dart';
import '../../models/post_model.dart';
import '../shared/music_picker_screen.dart';
import '../shared/music_editor_screen.dart';
import '../shared/final_post_screen.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class WavesEditorScreen extends StatefulWidget {
  final List<File> files;
  final String? initialCaption;
  final double playbackSpeed;
  final MusicTrack? initialMusic;
  final int? trimStartSeconds;
  final bool isGlimpse;
  final bool isWaves;

  const WavesEditorScreen({
    super.key,
    required this.files,
    this.initialCaption,
    this.playbackSpeed = 1.0,
    this.initialMusic,
    this.trimStartSeconds,
    this.isGlimpse = true,
    this.isWaves = false,
  });

  @override
  State<WavesEditorScreen> createState() => _WavesEditorScreenState();
}

class _TextOverlay {
  String text;
  Offset position;
  double scale;
  Color color = Colors.white;

  _TextOverlay({
    required this.text,
    required this.position,
    this.scale = 1.0,
  });
}

class _DrawPath {
  final List<Offset> points = [];
  Color color;
  double strokeWidth;

  _DrawPath({required this.color, required this.strokeWidth});
}

class _DrawPainter extends CustomPainter {
  final List<_DrawPath> paths;
  final _DrawPath? currentPath;

  _DrawPainter({required this.paths, this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in [...paths, if (currentPath != null) currentPath!]) {
      if (path.points.length < 2) continue;
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final uiPath = Path();
      uiPath.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        uiPath.lineTo(path.points[i].dx, path.points[i].dy);
      }
      canvas.drawPath(uiPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _WavesEditorScreenState extends State<WavesEditorScreen>
    with TickerProviderStateMixin {
  late TextEditingController _captionController;
  MusicTrack? _selectedMusic;
  int _selectedFilterIndex = 0;
  int _currentMediaIndex = 0;
  bool _showFilters = false;
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  int _trimStartSeconds = 0;
  Map<String, dynamic>? _selectedMusicStickerConfig;
  double _musicVolume = 1.0;
  double _originalAudioVolume = 1.0;
  double _editorBoxWidth = 1080.0;
  double _editorBoxHeight = 1920.0;

  int _bgAudioPosMs = 0;
  StreamSubscription<Duration>? _bgPosSub;

  // -- Video State --
  late List<VideoPlayerController?> _videoControllers;

  // -- Tools State --
  bool _isDrawingMode = false;
  final List<_DrawPath> _drawPaths = [];
  _DrawPath? _currentDrawPath;
  Color _currentDrawColor = Colors.white;

  final List<_TextOverlay> _textOverlays = [];
  bool _isAddingText = false;
  final FocusNode _textFocusNode = FocusNode();
  final TextEditingController _textOverlayController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<String> _emojiStickers = [
    "😍",
    "🔥",
    "✨",
    "🎉",
    "❤️",
    "😂",
    "👍",
    "🙏",
    "💯",
    "🚀",
  ];

  final List<Map<String, dynamic>> _carouselEffects = [
    {'id': 'none', 'label': 'Normal'},
    {'id': 'aesthetic', 'label': 'Paris'},
    {'id': 'suave', 'label': 'Oslo'},
    {'id': 'losangeles', 'label': 'L.A.'},
    {'id': 'bw', 'label': 'Classic'},
    {'id': 'zohan', 'label': 'Tokyo'},
    {'id': 'lowlight', 'label': 'Melbourne'},
    {'id': 'camcorder', 'label': 'VHS'},
    {'id': 'vivid', 'label': 'Jakarta'},
    {'id': 'vintage', 'label': 'Retro'},
    {'id': 'noir', 'label': 'Noir'},
    {'id': 'warm', 'label': 'Golden'},
    {'id': 'cool', 'label': 'Moody'},
    {'id': 'dream', 'label': 'Dream'},
    {'id': 'cinematic', 'label': 'Cinema'},
    {'id': 'fade', 'label': 'Lo-Fi'},
    {'id': 'dramatic', 'label': 'Dramatic'},
    {'id': 'sunset', 'label': 'Peach'},
  ];

  ColorFilter _getActiveColorFilter(int index) {
    if (index == 0) {
      return const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    final effectId = _carouselEffects[index]['id'];
    switch (effectId) {
      case 'aesthetic': return ColorFilter.matrix(PresetFilters.reyes.matrix);
      case 'suave': return ColorFilter.matrix(PresetFilters.slumber.matrix);
      case 'losangeles': return ColorFilter.matrix(PresetFilters.valencia.matrix);
      case 'bw': return ColorFilter.matrix(PresetFilters.willow.matrix);
      case 'zohan': return ColorFilter.matrix(PresetFilters.juno.matrix);
      case 'lowlight': return ColorFilter.matrix(PresetFilters.gingham.matrix);
      case 'camcorder': return ColorFilter.matrix(PresetFilters.stinson.matrix);
      case 'vivid': return ColorFilter.matrix(PresetFilters.clarendon.matrix);
      case 'vintage': return ColorFilter.matrix(PresetFilters.maven.matrix);
      case 'noir': return ColorFilter.matrix(PresetFilters.moon.matrix);
      case 'warm': return ColorFilter.matrix(PresetFilters.rise.matrix);
      case 'cool': return ColorFilter.matrix(PresetFilters.amaro.matrix);
      case 'dream': return ColorFilter.matrix(PresetFilters.ludwig.matrix);
      case 'cinematic': return ColorFilter.matrix(PresetFilters.xProII.matrix);
      case 'fade': return ColorFilter.matrix(PresetFilters.brooklyn.matrix);
      case 'dramatic': return ColorFilter.matrix(PresetFilters.mayfair.matrix);
      case 'sunset': return ColorFilter.matrix(PresetFilters.aden.matrix);
      default: return const ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  Map<String, dynamic> _getEffectLayers(int index) {
    if (index == 0) {
      return {'blur': 0.0, 'vignette': 0.0, 'blendColor': null, 'blendMode': null, 'tint': null, 'lightLeak': null, 'vhsUI': false};
    }
    final effectId = _carouselEffects[index]['id'];
    switch (effectId) {
      case 'aesthetic': return {'blur': 0.4, 'vignette': 0.1, 'blendColor': const Color(0x1AFFA500), 'blendMode': BlendMode.softLight, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      case 'suave': return {'blur': 0.8, 'vignette': 0.15, 'blendColor': const Color(0x22FFC0CB), 'blendMode': BlendMode.overlay, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      case 'losangeles': return {'blur': 0.0, 'vignette': 0.15, 'blendColor': const Color(0x33FF8C00), 'blendMode': BlendMode.screen, 'tint': null, 'lightLeak': [const Color(0x22FF4500), Colors.transparent], 'vhsUI': false};
      case 'zohan': return {'blur': 0.0, 'vignette': 0.25, 'blendColor': const Color(0x2200CED1), 'blendMode': BlendMode.hardLight, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      case 'lowlight': return {'blur': 0.0, 'vignette': 0.0, 'blendColor': const Color(0x22FFFFFF), 'blendMode': BlendMode.screen, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      case 'camcorder': return {'blur': 0.2, 'vignette': 0.6, 'blendColor': const Color(0x228B4513), 'blendMode': BlendMode.colorBurn, 'tint': null, 'lightLeak': [const Color(0x44FF0000), const Color(0x00FF0000)], 'vhsUI': true};
      case 'dramatic': return {'blur': 0.0, 'vignette': 0.4, 'blendColor': const Color(0x44000000), 'blendMode': BlendMode.softLight, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      case 'sunset': return {'blur': 0.0, 'vignette': 0.1, 'blendColor': const Color(0x22FF7F50), 'blendMode': BlendMode.overlay, 'tint': null, 'lightLeak': [const Color(0x33FFB6C1), Colors.transparent], 'vhsUI': false};
      case 'vintage': return {'blur': 0.4, 'vignette': 0.5, 'blendColor': const Color(0x33A0522D), 'blendMode': BlendMode.exclusion, 'tint': null, 'lightLeak': [const Color(0x44FFA500), Colors.transparent], 'vhsUI': false};
      case 'dream': return {'blur': 2.0, 'vignette': 0.0, 'blendColor': const Color(0x22E6E6FA), 'blendMode': BlendMode.lighten, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      case 'noir': return {'blur': 0.0, 'vignette': 0.6, 'blendColor': const Color(0x66000000), 'blendMode': BlendMode.multiply, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      case 'fade': return {'blur': 0.0, 'vignette': 0.4, 'blendColor': const Color(0x33B0C4DE), 'blendMode': BlendMode.screen, 'tint': null, 'lightLeak': [const Color(0x228A2BE2), Colors.transparent], 'vhsUI': false};
      case 'cinematic': return {'blur': 0.0, 'vignette': 0.5, 'blendColor': const Color(0x33004080), 'blendMode': BlendMode.overlay, 'tint': null, 'lightLeak': null, 'vhsUI': true};
      case 'warm': return {'blur': 0.0, 'vignette': 0.2, 'blendColor': const Color(0x22FFD700), 'blendMode': BlendMode.softLight, 'tint': null, 'lightLeak': [const Color(0x33FFA500), Colors.transparent], 'vhsUI': false};
      case 'cool': return {'blur': 0.0, 'vignette': 0.3, 'blendColor': const Color(0x1A0000FF), 'blendMode': BlendMode.overlay, 'tint': null, 'lightLeak': null, 'vhsUI': false};
      default: return {'blur': 0.0, 'vignette': 0.0, 'blendColor': null, 'blendMode': null, 'tint': null, 'lightLeak': null, 'vhsUI': false};
    }
  }

  @override
  void initState() {
    super.initState();
    AudioLifecycleManager.instance.register(_bgAudioPlayer);

    _bgPosSub = _bgAudioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _bgAudioPosMs = pos.inMilliseconds);
    });

    _captionController = TextEditingController(
      text: widget.initialCaption ?? "",
    );
    _selectedMusic = widget.initialMusic;
    _trimStartSeconds = widget.trimStartSeconds ?? 0;
    if (_selectedMusic != null) {
      _playSelectedMusic();
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize Video Controllers
    _videoControllers = List.generate(widget.files.length, (i) {
      final file = widget.files[i];
      final pathLower = file.path.toLowerCase();
      final isVideo = pathLower.endsWith('.mp4') ||
          pathLower.endsWith('.mov') ||
          pathLower.endsWith('.mkv') ||
          pathLower.endsWith('.avi') ||
          pathLower.endsWith('.webm') ||
          pathLower.endsWith('.3gp') ||
          pathLower.endsWith('.m4v') ||
          pathLower.contains('video');
      debugPrint('[WavesEditor] File[$i]: ${file.path} isVideo=$isVideo');
      if (isVideo) {
        final ctrl = VideoPlayerController.file(
          file,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        ctrl.initialize().then((_) async {
          if (mounted) setState(() {});
          await ctrl.setPlaybackSpeed(widget.playbackSpeed);
          await ctrl.setLooping(true);
          if (_selectedMusic != null) {
            await ctrl.setVolume(_originalAudioVolume);
          }
          // Auto-play first video
          if (i == 0) await ctrl.play();
        });
        return ctrl;
      }
      return null;
    });
  }

  Future<void> _playSelectedMusic() async {
    if (_selectedMusic == null) {
      for (final ctrl in _videoControllers) {
        if (ctrl != null && ctrl.value.isInitialized) {
          await ctrl.setVolume(1.0);
        }
      }
      await _bgAudioPlayer.stop();
      return;
    }
    try {
      for (final ctrl in _videoControllers) {
        if (ctrl != null && ctrl.value.isInitialized) {
          await ctrl.setVolume(_originalAudioVolume);
        }
      }
      await _bgAudioPlayer.setUrl(_selectedMusic!.previewUrl);
      await _bgAudioPlayer.seek(Duration(seconds: _trimStartSeconds));
      await _bgAudioPlayer.setVolume(_musicVolume);
      await _bgAudioPlayer.setLoopMode(LoopMode.one);
      await _bgAudioPlayer.play();
    } catch (e) {
      debugPrint("Editor Audio Error: $e");
    }
  }

  @override
  void dispose() {
    _bgPosSub?.cancel();
    AudioLifecycleManager.instance.unregister(_bgAudioPlayer);
    _bgAudioPlayer.stop().whenComplete(() => _bgAudioPlayer.dispose());
    for (var ctrl in _videoControllers) {
      ctrl?.dispose();
    }
    _captionController.dispose();
    _textOverlayController.dispose();
    _textFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _publishWave() async {
    KnockHaptics.tap();

    await _bgAudioPlayer.stop();
    if (!mounted) return;

    final serializedTexts = _textOverlays.map((t) => {
      'text': t.text,
      'x': t.position.dx / _editorBoxWidth,
      'y': t.position.dy / _editorBoxHeight,
      'scale': t.scale,
      'color': t.color.toARGB32(),
    }).toList();

    final serializedPaths = _drawPaths.map((p) => {
      'color': p.color.toARGB32(),
      'strokeWidth': p.strokeWidth,
      'points': p.points.map((pt) => {'x': pt.dx / _editorBoxWidth, 'y': pt.dy / _editorBoxHeight}).toList(),
    }).toList();

    // Generate a thumbnail for the video if it's the first file
    File? coverFile;
    bool isVideo = false;
    if (widget.files.isNotEmpty) {
      try {
        final pathLower = widget.files.first.path.toLowerCase();
        isVideo = pathLower.endsWith('.mp4') ||
            pathLower.endsWith('.mov') ||
            pathLower.endsWith('.mkv') ||
            pathLower.endsWith('.avi') ||
            pathLower.endsWith('.webm') ||
            pathLower.endsWith('.3gp') ||
            pathLower.endsWith('.m4v');
        
        if (isVideo) {
          final tempDir = await getTemporaryDirectory();
          final thumbPath = await VideoThumbnail.thumbnailFile(
            video: widget.files.first.path,
            thumbnailPath: tempDir.path,
            imageFormat: ImageFormat.JPEG,
            quality: 75,
          );
          if (thumbPath != null) {
            coverFile = File(thumbPath);
          }
        }
      } catch (e) {
        debugPrint('Failed to generate thumbnail: $e');
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FinalPostScreen(
          files: widget.files,
          initialCaption: _captionController.text.trim(),
          isGlimpse: widget.isGlimpse,
          isWaves: widget.isWaves,
          initialMusic: _selectedMusic,
          initialTrimSeconds: _trimStartSeconds,
          initialMusicStickerConfig: _selectedMusicStickerConfig,
          initialMusicVolume: _musicVolume,
          initialOriginalAudioVolume: _originalAudioVolume,
          initialFilterIndex: _selectedFilterIndex > 0 ? _selectedFilterIndex : null,
          initialTextOverlays: serializedTexts.isEmpty ? null : serializedTexts,
          initialDrawPaths: serializedPaths.isEmpty ? null : serializedPaths,
          isVideoPost: isVideo,
          videoHasSound: _selectedMusic == null,
          coverImageFile: coverFile, // Pass the generated thumbnail!
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── 1. FULL SCREEN MEDIA ───
          _buildMedia(size),

          // ─── 4. GRADIENTS ───
          if (!_isDrawingMode && !_isAddingText)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 160,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_isDrawingMode && !_isAddingText)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 280,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ─── 5. MAIN UI OVERLAY ───
          if (!_isAddingText)
            SafeArea(
              bottom: bottomInset == 0,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR
                    if (!_isDrawingMode) _buildTopBar(),

                    // DRAWING TOP BAR
                    if (_isDrawingMode) _buildDrawingTopBar(),

                    const SizedBox(height: 12),

                    // Progress line strip
                    if (widget.files.length > 1 && !_isDrawingMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: List.generate(widget.files.length, (i) {
                            final isActive = i == _currentMediaIndex;
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 2.5,
                                margin: EdgeInsets.only(
                                  right: i < widget.files.length - 1 ? 4 : 0,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                    // ─── MIDDLE: Tools pill on right ───
                    Expanded(
                      child: Stack(
                        children: [
                          if (!_isDrawingMode)
                            Positioned(
                              right: 16,
                              top: 8,
                              child: _buildToolPanel(),
                            ),

                          // Active Filter Name badge
                          if (_selectedFilterIndex > 0 && !_isDrawingMode)
                            Positioned(
                              bottom: 8,
                              left: 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      _carouselEffects[_selectedFilterIndex]['label'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_showFilters && !_isDrawingMode)
                      _buildFiltersScroller(),

                    if (_selectedMusic != null && !_isDrawingMode && !(_selectedMusicStickerConfig?['showSticker'] ?? true))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedMusic!.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        Text(
                                          _selectedMusic!.artist,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      KnockHaptics.tap();
                                      setState(() => _selectedMusic = null);
                                      _playSelectedMusic();
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (!_isDrawingMode) _buildBottomBar(),
                  ],
                ),
              ),
            ),

          // ─── 6. FULL SCREEN TEXT INPUT OVERLAY ───
          if (_isAddingText) _buildTextInputOverlay(size),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(
                            alpha: _pulseAnim.value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isGlimpse ? "GLIMPSE" : "WAVES",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          if (widget.files.length > 1)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    "${_currentMediaIndex + 1} / ${widget.files.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawingTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Done button
          GestureDetector(
            onTap: () => setState(() => _isDrawingMode = false),
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
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Color picker dots
          ...[
            Colors.white,
            Colors.black,
            Colors.redAccent,
            Colors.blueAccent,
            Colors.greenAccent,
            Colors.yellowAccent,
          ].map((color) {
            final isSelected = _currentDrawColor == color;
            return GestureDetector(
              onTap: () => setState(() => _currentDrawColor = color),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : Border.all(color: Colors.transparent),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDrawingLayer() {
    return GestureDetector(
      onPanStart: (details) {
        if (!_isDrawingMode) return;
        setState(() {
          _currentDrawPath = _DrawPath(
            color: _currentDrawColor,
            strokeWidth: 5.0,
          );
          _currentDrawPath!.points.add(details.localPosition);
        });
      },
      onPanUpdate: (details) {
        if (!_isDrawingMode || _currentDrawPath == null) return;
        setState(() {
          _currentDrawPath!.points.add(details.localPosition);
        });
      },
      onPanEnd: (details) {
        if (!_isDrawingMode || _currentDrawPath == null) return;
        setState(() {
          _drawPaths.add(_currentDrawPath!);
          _currentDrawPath = null;
        });
      },
      child: Container(
        color: _isDrawingMode ? Colors.transparent : null,
        child: CustomPaint(
          size: Size.infinite,
          painter: _DrawPainter(
            paths: _drawPaths,
            currentPath: _currentDrawPath,
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputOverlay(Size size) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_textOverlayController.text.trim().isNotEmpty) {
                        setState(() {
                          _textOverlays.add(
                            _TextOverlay(
                              text: _textOverlayController.text.trim(),
                              position: Offset(
                                size.width / 2 - 50,
                                size.height / 2,
                              ),
                            ),
                          );
                        });
                      }
                      _textOverlayController.clear();
                      setState(() => _isAddingText = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: TextField(
                  controller: _textOverlayController,
                  focusNode: _textFocusNode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Type something...",
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Stickers",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _emojiStickers.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _textOverlays.add(
                            _TextOverlay(
                              text: _emojiStickers[index],
                              position: const Offset(150, 300),
                              scale: 2.0,
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: Center(
                        child: Text(
                          _emojiStickers[index],
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolPanel() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _toolIcon(
                    icon: Icons.title_rounded,
                    tooltip: "Text",
                    onTap: () {
                      setState(() => _isAddingText = true);
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _textFocusNode.requestFocus(),
                      );
                    },
                  ),
                  _toolDivider(),
                  _toolIcon(
                    icon: Icons.alternate_email_rounded,
                    tooltip: "Mention",
                    onTap: () {
                      _textOverlayController.text = "@";
                      setState(() => _isAddingText = true);
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _textFocusNode.requestFocus(),
                      );
                    },
                  ),
                  _toolDivider(),
                  _toolIcon(
                    icon: Icons.mood_rounded,
                    tooltip: "Stickers",
                    onTap: _showStickerPicker,
                  ),
                  _toolDivider(),
                  _toolIcon(
                    icon: _selectedMusic != null
                        ? Icons.graphic_eq_rounded
                        : Icons.queue_music_rounded,
                    tooltip: "Music",
                    onTap: () async {
                      KnockHaptics.tap();
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MusicPickerScreen(),
                        ),
                      );
                      if (result != null && result is MusicTrack) {
                        if (!mounted) return;
                        // Open new MusicOverlayScreen
                        final isVideo =
                            _videoControllers[_currentMediaIndex] != null;
                        final overlayResult = await Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (_, __, ___) => MusicOverlayScreen(
                              track: result,
                              isVideo: isVideo,
                            ),
                          ),
                        );
                        
                        if (overlayResult != null && overlayResult is Map) {
                          // Once finished with overlay, set active music
                          setState(() {
                            _selectedMusic = overlayResult['track'] as MusicTrack;
                            _trimStartSeconds = overlayResult['trimStartSeconds'] as int;
                            _selectedMusicStickerConfig = (overlayResult['stickerConfig'] as Map?)?.cast<String, dynamic>();
                            _musicVolume = overlayResult['musicVolume'] as double? ?? 1.0;
                            _originalAudioVolume = overlayResult['originalVolume'] as double? ?? _originalAudioVolume;
                          });
                          _playSelectedMusic();
                        }
                      }
                    },
                  ),
                  _toolDivider(),
                  _toolIcon(
                    icon: _showFilters
                        ? Icons.blur_on_rounded
                        : Icons.blur_linear_rounded,
                    tooltip: "Effects",
                    active: _showFilters,
                    onTap: () => setState(() => _showFilters = !_showFilters),
                  ),
                  _toolDivider(),
                  _toolIcon(
                    icon: Icons.edit_rounded,
                    tooltip: "Draw",
                    onTap: () => setState(() => _isDrawingMode = true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        onTap();
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 52,
          height: 46,
          color: Colors.transparent,
          child: Icon(
            icon,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.85),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _toolDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  List<Widget> _buildEffectOverlayLayers(int index) {
    if (index == 0) return [];
    
    final layers = _getEffectLayers(index);
    final tint = layers['tint'] as Color?;
    final vignetteIntensity = (layers['vignette'] as double?) ?? 0.0;
    final lightLeak = layers['lightLeak'] as List<Color>?;
    final vhsUI = (layers['vhsUI'] as bool?) ?? false;
    
    final List<Widget> overlays = [];

    if (tint != null) {
      overlays.add(
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: tint,
            ),
          ),
        ),
      );
    }

    if (lightLeak != null && lightLeak.length == 2) {
      overlays.add(
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: const Alignment(0.2, 0.5),
                  colors: lightLeak,
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
      );
      overlays.add(
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomRight,
                  end: const Alignment(0.5, 0.2),
                  colors: [lightLeak[0].withValues(alpha: 0.05), Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (vignetteIntensity > 0) {
      overlays.add(
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: vignetteIntensity * 0.4),
                    Colors.black.withValues(alpha: vignetteIntensity),
                  ],
                  stops: const [0.35, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (vhsUI) {
      final now = DateTime.now();
      final dateStr = '${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}.${now.year}';
      final formattedHour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final timeStr = '${formattedHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? "PM" : "AM"}';
      
      overlays.add(
        Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text(
                          '• REC',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 18,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Courier',
                            shadows: [Shadow(color: Colors.red, blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Courier',
                            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Courier',
                            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return overlays;
  }

  Widget _buildMedia(Size size) {
    if (widget.files.isEmpty) return const SizedBox.shrink();
    return PageView.builder(
      physics: _isDrawingMode
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: widget.files.length,
      onPageChanged: (i) {
        setState(() => _currentMediaIndex = i);
        // Autoplay logic for videos
        for (int j = 0; j < _videoControllers.length; j++) {
          if (_videoControllers[j] != null) {
            if (j == i) {
              _videoControllers[j]!.play();
            } else {
              _videoControllers[j]!.pause();
            }
          }
        }
      },
      itemBuilder: (context, i) {
        final vCtrl = _videoControllers[i];
        final isVideo = vCtrl != null;
        
        final layers = _getEffectLayers(_selectedFilterIndex);
        final blurSigma = (layers['blur'] as double?) ?? 0.0;
        final blendColor = layers['blendColor'] as Color?;
        final blendMode = layers['blendMode'] as BlendMode?;

        Widget preview = isVideo
            ? (vCtrl.value.isInitialized
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: vCtrl.value.size.width,
                          height: vCtrl.value.size.height,
                          child: VideoPlayer(vCtrl),
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ))
            : Image.file(widget.files[i], fit: BoxFit.cover);

        preview = ColorFiltered(
          colorFilter: _getActiveColorFilter(_selectedFilterIndex),
          child: preview,
        );

        if (blendColor != null && blendMode != null) {
          preview = ColorFiltered(
            colorFilter: ColorFilter.mode(blendColor, blendMode),
            child: preview,
          );
        }

        if (blurSigma > 0) {
          preview = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: TileMode.clamp,
            ),
            child: preview,
          );
        }

        return Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: LayoutBuilder(
              builder: (context, constraints) {
            if (_editorBoxWidth != constraints.maxWidth || _editorBoxHeight != constraints.maxHeight) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && (_editorBoxWidth != constraints.maxWidth || _editorBoxHeight != constraints.maxHeight)) {
                  setState(() {
                    _editorBoxWidth = constraints.maxWidth;
                    _editorBoxHeight = constraints.maxHeight;
                  });
                }
              });
            }

            // Scale constants removed since sticker is not draggable

            return Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        preview,
                        ..._buildEffectOverlayLayers(_selectedFilterIndex),
                      ],
                    ),
                  ),
                ),
                if (_selectedMusic != null && _selectedMusicStickerConfig != null)
                  RepaintBoundary(
                    child: MusicStickerWidget(
                      title: _selectedMusic!.title,
                      artist: _selectedMusic!.artist,
                      coverUrl: _selectedMusic!.coverUrl,
                      configData: _selectedMusicStickerConfig,
                      isPlaying: true, // AudioPlayer doesn't expose stream here easily without more state, true is safe for static view or we can use the same pattern as before
                      isEditable: true,
                      onConfigChanged: (config) {
                        setState(() {
                          _selectedMusicStickerConfig = config.toMap();
                        });
                      },
                    ),
                  ),

                // ─── DRAWING LAYER ───
                if (_drawPaths.isNotEmpty || _currentDrawPath != null || _isDrawingMode)
                  _buildDrawingLayer(),

                // ─── TEXT & STICKER OVERLAYS ───
                ..._textOverlays.map((overlay) {
                  return Positioned(
                    left: overlay.position.dx,
                    top: overlay.position.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          overlay.position += details.delta;
                        });
                      },
                      child: Text(
                        overlay.text,
                        style: TextStyle(
                          color: overlay.color,
                          fontSize: 32 * overlay.scale,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }
        ),
          ),
        );
      },
    );
  }

  Widget _buildFiltersScroller() {
    return Container(
      height: 94,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _carouselEffects.length,
        itemBuilder: (context, i) {
          final isActive = i == _selectedFilterIndex;
          return GestureDetector(
            onTap: () {
              KnockHaptics.tap();
              setState(() => _selectedFilterIndex = i);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: widget.files.isNotEmpty
                        ? ClipOval(
                            child: ColorFiltered(
                              colorFilter: _getActiveColorFilter(i),
                              child: _videoControllers.first != null
                                  ? Container(
                                      color: Colors.black38,
                                      child: const Icon(
                                        Icons.videocam,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : Image.file(
                                      widget.files.first,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          )
                        : const SizedBox(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _carouselEffects[i]['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caption field
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    height: 1.4,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: "Add a caption...",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Post Button
          GestureDetector(
            onTap: _publishWave,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isWaves ? "Post Wave" : "Post Glimpse",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
