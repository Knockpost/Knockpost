import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:just_audio/just_audio.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/audio_lifecycle_manager.dart';
import '../shared/music_picker_screen.dart';
import '../shared/music_editor_screen.dart';
import '../shared/final_post_screen.dart';

// ─── Tool Modes ───────────────────────────────────────────────────────────────

enum _EditorTool { none, filter, adjust, text, overlay, edit }

// ─── Widget ───────────────────────────────────────────────────────────────────

class MediaEditorScreen extends StatefulWidget {
  final List<File> files;
  final String? initialCaption;
  final double aspectRatio;
  final bool isGlimpse;

  const MediaEditorScreen({
    super.key,
    required this.files,
    this.initialCaption,
    this.aspectRatio = 4 / 5,
    this.isGlimpse = false,
  });

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  _EditorTool _activeTool = _EditorTool.none;
  int _selectedFilterIndex = 0;
  double _brightness = 0.0; // -1 to 1
  double _contrast = 1.0; // 0.5 to 1.5
  double _saturation = 1.0; // 0 to 2
  MusicTrack? _selectedMusic;
  int? _selectedMusicStyle;
  Map<String, dynamic>? _selectedMusicLyricsConfig;

  // Music overlay dragging state
  Offset? _musicOverlayPosition;
  double _musicOverlayScale = 1.0;
  double _musicOverlayRotation = 0.0;
  double _baseMusicOverlayScale = 1.0;
  double _baseMusicOverlayRotation = 0.0;
  Offset? _dragStartFocalPoint;
  Offset? _dragStartOverlayPos;
  double _editorBoxWidth = 1080.0;
  double _editorBoxHeight = 1350.0;
  final GlobalKey _previewBoundaryKey = GlobalKey();
  bool _isExportingPreview = false;

  // Text overlay
  final List<_TextOverlay> _overlays = [];
  _TextOverlay? _selectedOverlay;
  double _textBaseScale = 1.0;
  bool _isAddingText = false;
  final TextEditingController _textInputCtrl = TextEditingController();

  late AnimationController _toolbarAnimCtrl;
  late Animation<double> _toolbarAnim;
  late AnimationController _sheetAnimCtrl;
  late Animation<Offset> _sheetSlide;

  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  int _trimStartSeconds = 0;
  int _bgAudioPosMs = 0;
  StreamSubscription<Duration>? _bgPosSub;

  // ── Filter definitions ────────────────────────────────────────────────────
  final List<String> _filterNames = [
    'Original',
    'Vivid',
    'Warm',
    'Cool',
    'Noir',
    'Fade',
    'Chrome',
    'Sepia',
    'Cinematic',
    'Cyber',
  ];

  List<double> get _activeMatrix {
    final b = _brightness;
    final c = _contrast;
    final s = _saturation;

    // Build brightness+contrast+saturation matrix
    final base = _buildAdjustMatrix(b, c, s);

    // Apply filter on top
    return _combineMatrices(_filterMatrices[_selectedFilterIndex], base);
  }

  List<double> _buildAdjustMatrix(double b, double c, double s) {
    final sr = (1 - s) * 0.3086;
    final sg = (1 - s) * 0.6094;
    final sb = (1 - s) * 0.0820;
    final bv = b * 255;
    return [
      sr + s * c,
      sg,
      sb,
      0,
      bv,
      sr,
      sg + s * c,
      sb,
      0,
      bv,
      sr,
      sg,
      sb + s * c,
      0,
      bv,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _combineMatrices(List<double> a, List<double> b) {
    List<double> result = List.filled(20, 0.0);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 5; c++) {
        double val = 0.0;
        for (int k = 0; k < 4; k++) {
          val += a[r * 5 + k] * b[k * 5 + c];
        }
        if (c == 4) {
          val += a[r * 5 + 4]; // add translation from matrix a
        }
        result[r * 5 + c] = val;
      }
    }
    return result;
  }

  final List<List<double>> _filterMatrices = [
    // Original
    [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
    // Vivid
    [1.3, 0, 0, 0, 0, 0, 1.3, 0, 0, 0, 0, 0, 1.2, 0, 0, 0, 0, 0, 1, 0],
    // Warm
    [1.2, 0, 0, 0, 10, 0, 1.1, 0, 0, 5, 0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0],
    // Cool
    [0.9, 0, 0.1, 0, 0, 0, 1.0, 0.1, 0, 0, 0.1, 0, 1.2, 0, 10, 0, 0, 0, 1, 0],
    // Noir
    [
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
    ],
    // Fade
    [1, 0, 0, 0, 20, 0, 1, 0, 0, 20, 0, 0, 1, 0, 20, 0, 0, 0, 0.85, 0],
    // Chrome
    [1.3, 0.1, 0, 0, 0, 0, 1.1, 0.1, 0, 0, 0, 0, 1.2, 0, 0, 0, 0, 0, 1, 0],
    // Sepia
    [
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
    ],
    // Cinematic
    [1.3, 0.1, 0, 0, 10, 0, 1.1, 0.1, 0, 5, 0, 0.2, 1.3, 0, 20, 0, 0, 0, 1, 0],
    // Cyber
    [1.2, 0, 0.5, 0, 10, 0, 0.8, 0.5, 0, 0, 0.5, 0, 1.2, 0, 20, 0, 0, 0, 1, 0],
  ];

  // ── Monochrome Knockpost dark premium theme ─────────────────────────────────

  @override
  void initState() {
    super.initState();
    AudioLifecycleManager.instance.register(_bgAudioPlayer);
    _editorBoxHeight = _editorBoxWidth / widget.aspectRatio;

    _bgPosSub = _bgAudioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _bgAudioPosMs = pos.inMilliseconds);
    });

    _toolbarAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _toolbarAnim = CurvedAnimation(
      parent: _toolbarAnimCtrl,
      curve: Curves.easeOut,
    );
    _toolbarAnimCtrl.forward();

    _sheetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sheetSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _sheetAnimCtrl, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _bgPosSub?.cancel();
    AudioLifecycleManager.instance.unregister(_bgAudioPlayer);
    _bgAudioPlayer.stop().whenComplete(() => _bgAudioPlayer.dispose());
    _toolbarAnimCtrl.dispose();
    _sheetAnimCtrl.dispose();
    _textInputCtrl.dispose();
    super.dispose();
  }

  void _setTool(_EditorTool tool) {
    if (_activeTool == tool) {
      setState(() => _activeTool = _EditorTool.none);
      _sheetAnimCtrl.reverse();
    } else {
      setState(() => _activeTool = tool);
      _sheetAnimCtrl.forward(from: 0);
    }
  }

  Future<void> _waitForPreviewFrame() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  Future<File> _capturePreviewToFile(Directory tempDir, int index) async {
    final boundaryContext = _previewBoundaryKey.currentContext;
    if (boundaryContext == null) {
      throw StateError('Preview boundary is not ready.');
    }

    final boundary =
        boundaryContext.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Preview boundary render object is missing.');
    }

    final double pixelRatio = _editorBoxWidth > 0
        ? (1080 / _editorBoxWidth)
        : (1080 / MediaQuery.sizeOf(context).width.clamp(1.0, 1080.0));

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode edited image.');
      }

      final outputFile = File(
        '${tempDir.path}/edited_${index}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());
      return outputFile;
    } finally {
      image.dispose();
    }
  }

  Future<List<File>> _exportProcessedImages() async {
    final tempDir = await Directory.systemTemp.createTemp('knockpost_media_');
    final originalIndex = _currentIndex;

    setState(() {
      _selectedOverlay = null;
      _activeTool = _EditorTool.none;
      _isExportingPreview = true;
    });
    _sheetAnimCtrl.reverse();

    final List<File> exportedFiles = [];

    try {
      for (int i = 0; i < widget.files.length; i++) {
        if (_currentIndex != i) {
          setState(() => _currentIndex = i);
        }
        await _waitForPreviewFrame();
        exportedFiles.add(await _capturePreviewToFile(tempDir, i));
      }
      return exportedFiles;
    } finally {
      if (mounted && _currentIndex != originalIndex) {
        setState(() => _currentIndex = originalIndex);
      }
      if (mounted) {
        setState(() => _isExportingPreview = false);
      }
    }
  }

  Future<void> _onNext() async {
    if (_isExportingPreview) return;
    KnockHaptics.tap();
    await _bgAudioPlayer.stop();
    if (!mounted) return;

    late final List<File> processedFiles;
    try {
      processedFiles = await _exportProcessedImages();
    } catch (e) {
      debugPrint('Media export error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not export the edited images. Please try again.',
          ),
        ),
      );
      return;
    }

    final serializedTexts = _overlays
        .map(
          (t) => {
            'text': t.text,
            'x': t.position.dx / _editorBoxWidth,
            'y': t.position.dy / _editorBoxHeight,
            'scale': t.scale,
            'color': t.color.toARGB32(),
          },
        )
        .toList();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FinalPostScreen(
          files: processedFiles,
          initialCaption: widget.initialCaption,
          isGlimpse: widget.isGlimpse,
          mediaAspectRatio: widget.aspectRatio,
          mediaIsBaked: true,
          initialMusic: _selectedMusic,
          initialTrimSeconds: _trimStartSeconds,
          initialMusicStyle: _selectedMusicStyle,
          initialMusicCoverUrl: _selectedMusic?.coverUrl,
          initialMusicLyrics: _selectedMusic?.syncedLyrics,
          initialMusicLyricsConfig: _selectedMusicLyricsConfig,
          initialMusicOverlayX: _musicOverlayPosition != null
              ? _musicOverlayPosition!.dx / _editorBoxWidth
              : null,
          initialMusicOverlayY: _musicOverlayPosition != null
              ? _musicOverlayPosition!.dy / _editorBoxHeight
              : null,
          initialMusicOverlayScale: _musicOverlayScale,
          initialMusicOverlayRotation: _musicOverlayRotation,
          initialFilterIndex: _selectedFilterIndex > 0
              ? _selectedFilterIndex
              : null,
          initialTextOverlays: serializedTexts.isEmpty ? null : serializedTexts,
        ),
      ),
    );
  }

  Future<void> _pickMusic() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPickerScreen()),
    );
    if (result != null && result is MusicTrack && mounted) {
      final isVideo =
          widget.files.isNotEmpty &&
          (widget.files.first.path.toLowerCase().endsWith('.mp4') ||
              widget.files.first.path.toLowerCase().endsWith('.mov'));

      final overlayResult = await Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) =>
              MusicOverlayScreen(track: result, isVideo: isVideo),
        ),
      );

      if (overlayResult != null && overlayResult is Map && mounted) {
        debugPrint('[MediaEditor] overlayResult keys: ${overlayResult.keys}');
        debugPrint(
          '[MediaEditor] styleIndex from overlay: ${overlayResult['styleIndex']}',
        );
        setState(() {
          _selectedMusic = overlayResult['track'] as MusicTrack;
          _trimStartSeconds = overlayResult['trimStartSeconds'] as int;
          _selectedMusicStyle = overlayResult['styleIndex'] as int?;
          _selectedMusicLyricsConfig =
              (overlayResult['lyricsConfig'] as Map?)?.cast<String, dynamic>();
          _musicOverlayPosition = null;
          _musicOverlayScale = 1.0;
          _musicOverlayRotation = 0.0;
          _activeTool = _EditorTool.none;
        });
        debugPrint(
          '[MediaEditor] _selectedMusicStyle after setState: $_selectedMusicStyle',
        );
        debugPrint(
          '[MediaEditor] _selectedMusic title: ${_selectedMusic?.title}',
        );
        debugPrint(
          '[MediaEditor] _selectedMusic coverUrl: ${_selectedMusic?.coverUrl}',
        );
        _sheetAnimCtrl.reverse();
        _playSelectedMusic();
      } else {
        debugPrint(
          '[MediaEditor] overlayResult was null or not a Map: $overlayResult',
        );
      }
    }
  }

  Future<void> _playSelectedMusic() async {
    if (_selectedMusic == null) {
      await _bgAudioPlayer.stop();
      return;
    }
    try {
      await _bgAudioPlayer.setUrl(_selectedMusic!.previewUrl);
      await _bgAudioPlayer.seek(Duration(seconds: _trimStartSeconds));
      await _bgAudioPlayer.setLoopMode(LoopMode.one);
      await _bgAudioPlayer.play();
    } catch (e) {
      debugPrint('MediaEditor bg audio error: $e');
    }
  }

  void _addTextOverlay(String text) {
    if (text.trim().isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _overlays.add(
        _TextOverlay(
          text: text.trim(),
          position: Offset(size.width / 2 - 80, size.height / 2 - 100),
        ),
      );
      _isAddingText = false;
    });
    _textInputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final file = widget.files[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. The Media + Overlay (Confined to 4:5 ratio) ─────────────
            Center(
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (_editorBoxWidth != constraints.maxWidth ||
                        _editorBoxHeight != constraints.maxHeight) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _editorBoxWidth = constraints.maxWidth;
                            _editorBoxHeight = constraints.maxHeight;
                          });
                        }
                      });
                    }

                    const double minScale = 0.20;
                    const double maxScale = 2.5;
                    final pos =
                        _musicOverlayPosition ??
                        defaultMusicLyricsOverlayOffset(
                          frameWidth: constraints.maxWidth,
                          frameHeight: constraints.maxHeight,
                          lyricsConfigData: _selectedMusicLyricsConfig,
                        );

                    return RepaintBoundary(
                      key: _previewBoundaryKey,
                      child: GestureDetector(
                        // Pinch anywhere on the media to resize selected text
                        onScaleStart: _selectedOverlay != null
                            ? (details) {
                                _textBaseScale = _selectedOverlay!.scale;
                              }
                            : null,
                        onScaleUpdate: _selectedOverlay != null
                            ? (details) {
                                if (details.pointerCount >= 2) {
                                  setState(() {
                                    _selectedOverlay!.scale =
                                        (_textBaseScale * details.scale)
                                            .clamp(0.4, 4.0)
                                            .toDouble();
                                  });
                                }
                              }
                            : null,
                        onTap: () {
                          if (_selectedOverlay != null) {
                            setState(() => _selectedOverlay = null);
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix(_activeMatrix),
                              child: Image.file(file, fit: BoxFit.cover),
                            ),
                            if (_selectedMusic != null &&
                                _selectedMusicStyle != null &&
                                _selectedMusicStyle != 0)
                              Positioned(
                                left: pos.dx,
                                top: pos.dy,
                                child: GestureDetector(
                                  onScaleStart: (details) {
                                    _baseMusicOverlayScale = _musicOverlayScale;
                                    _baseMusicOverlayRotation =
                                        _musicOverlayRotation;
                                    _dragStartFocalPoint = details.focalPoint;
                                    _dragStartOverlayPos = pos;
                                  },
                                  onScaleUpdate: (details) {
                                    final delta =
                                        details.focalPoint -
                                        (_dragStartFocalPoint ??
                                            details.focalPoint);
                                    final newScale =
                                        (_baseMusicOverlayScale * details.scale)
                                            .clamp(minScale, maxScale)
                                            .toDouble();
                                    setState(() {
                                      _musicOverlayPosition =
                                          (_dragStartOverlayPos ?? pos) + delta;
                                      _musicOverlayScale = newScale;
                                      if (details.pointerCount >= 2) {
                                        _musicOverlayRotation =
                                            _baseMusicOverlayRotation +
                                            details.rotation;
                                      }
                                    });
                                  },
                                  child: Transform.rotate(
                                    angle: _musicOverlayRotation,
                                    alignment: Alignment.center,
                                    child: Transform.scale(
                                      scale: _musicOverlayScale,
                                      alignment: Alignment.center,
                                      child: RepaintBoundary(
                                        child: MusicStyleOverlayWidget(
                                          styleIndex: _selectedMusicStyle!,
                                          title: _selectedMusic!.title,
                                          artist: _selectedMusic!.artist,
                                          coverUrl: _selectedMusic!.coverUrl,
                                          lyricsLrc: _selectedMusic!.syncedLyrics,
                                          lyricsConfigData:
                                              _selectedMusicLyricsConfig,
                                          timelinePositionMs: _bgAudioPosMs,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // ── TEXT OVERLAYS ──
                            ..._overlays.map((ov) {
                              final isSelected = ov == _selectedOverlay;
                              return Positioned(
                                left: ov.position.dx,
                                top: ov.position.dy,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedOverlay = isSelected ? null : ov;
                                  }),
                                  onPanUpdate: (d) =>
                                      setState(() => ov.position += d.delta),
                                  onLongPress: () => setState(() {
                                    if (_selectedOverlay == ov) {
                                      _selectedOverlay = null;
                                    }
                                    _overlays.remove(ov);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      ov.text,
                                      style: TextStyle(
                                        color: ov.color,
                                        fontSize: 28 * ov.scale,
                                        fontWeight: FontWeight.bold,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── 2. Top gradient ──────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
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

            // ── 3. Bottom gradient ───────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 300,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom gradient etc ────────────────────────────────────────

            // ── 5. Multi-image strip (top left) ──────────────────────────
            if (widget.files.length > 1)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 60),
                  child: Row(
                    children: List.generate(widget.files.length, (i) {
                      final isActive = i == _currentIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _currentIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isActive ? 36 : 28,
                          height: isActive ? 36 : 28,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isActive ? Colors.white : Colors.white38,
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(
                              widget.files[i],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

            // ── 7. Main UI overlay ────────────────────────────────────────
            if (!_isAddingText)
              SafeArea(
                child: Column(
                  children: [
                    // TOP BAR
                    _buildTopBar(),
                    const Spacer(),
                    // TOOL SHEET (filter / adjust / text / music)
                    if (_activeTool != _EditorTool.none)
                      SlideTransition(
                        position: _sheetSlide,
                        child: _buildToolSheet(),
                      ),
                    // BOTTOM TOOLBAR
                    FadeTransition(
                      opacity: _toolbarAnim,
                      child: _buildBottomBar(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // ── 8. Full-screen text input overlay ────────────────────────
            if (_isAddingText) _buildTextInputOverlay(size),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Back
          _glassButton(
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          // Label pill
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
                  ),
                ),
                child: const Text(
                  'EDIT PHOTO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Next
          GestureDetector(
            onTap: _isExportingPreview ? null : _onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _isExportingPreview
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM TOOLBAR ─────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _toolBtn(
                    Icons.layers_rounded,
                    'Overlay',
                    _EditorTool.overlay,
                  ),
                  const SizedBox(width: 12),
                  _toolBtn(Icons.crop_rotate_rounded, 'Edit', _EditorTool.edit),
                  const SizedBox(width: 12),
                  _toolBtn(
                    Icons.auto_awesome_rounded,
                    'Filter',
                    _EditorTool.filter,
                  ),
                  const SizedBox(width: 12),
                  _toolBtn(Icons.tune_rounded, 'Adjust', _EditorTool.adjust),
                  const SizedBox(width: 12),
                  _toolBtn(Icons.text_fields_rounded, 'Text', _EditorTool.text),
                  const SizedBox(width: 12),
                  _musicToolBtn(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, _EditorTool tool) {
    final isActive = _activeTool == tool;
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        if (tool == _EditorTool.text) {
          setState(() {
            _activeTool = _EditorTool.none;
            _isAddingText = true;
          });
          _sheetAnimCtrl.reverse();
        } else {
          _setTool(tool);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _musicToolBtn() {
    final hasMusic = _selectedMusic != null;
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        _pickMusic();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasMusic
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasMusic
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasMusic ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
              size: 22,
              color: hasMusic
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 4),
            Text(
              hasMusic ? 'Music ✓' : 'Music',
              style: TextStyle(
                fontSize: 10,
                fontWeight: hasMusic ? FontWeight.w700 : FontWeight.w500,
                color: hasMusic
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TOOL SHEETS ────────────────────────────────────────────────────────────

  Widget _buildToolSheet() {
    switch (_activeTool) {
      case _EditorTool.filter:
        return _buildFilterSheet();
      case _EditorTool.adjust:
        return _buildAdjustSheet();
      case _EditorTool.overlay:
        return _buildPlaceholderSheet('Overlay options coming soon');
      case _EditorTool.edit:
        return _buildPlaceholderSheet('Crop & Rotate coming soon');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPlaceholderSheet(String text) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }

  // Filter carousel
  Widget _buildFilterSheet() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filterNames.length,
        itemBuilder: (context, i) {
          final isSelected = _selectedFilterIndex == i;
          return GestureDetector(
            onTap: () {
              KnockHaptics.tap();
              setState(() => _selectedFilterIndex = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              margin: const EdgeInsets.only(right: 10, bottom: 8),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(_filterMatrices[i]),
                        child: Image.file(
                          widget.files.first,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _filterNames[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 0.2,
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

  // Adjust sliders
  Widget _buildAdjustSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSlider(
            label: 'Brightness',
            icon: Icons.brightness_6_rounded,
            value: (_brightness + 1) / 2,
            onChanged: (v) => setState(() => _brightness = v * 2 - 1),
          ),
          const SizedBox(height: 14),
          _buildSlider(
            label: 'Contrast',
            icon: Icons.contrast_rounded,
            value: (_contrast - 0.5) / 1.0,
            onChanged: (v) => setState(() => _contrast = v + 0.5),
          ),
          const SizedBox(height: 14),
          _buildSlider(
            label: 'Saturation',
            icon: Icons.palette_rounded,
            value: _saturation / 2,
            onChanged: (v) => setState(() => _saturation = v * 2),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0).toDouble(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── TEXT INPUT OVERLAY ─────────────────────────────────────────────────────

  Widget _buildTextInputOverlay(Size size) {
    return GestureDetector(
      onTap: () {
        setState(() => _isAddingText = false);
        _textInputCtrl.clear();
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: TextField(
                        controller: _textInputCtrl,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type something…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 22,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _glassButton(
                      onTap: () {
                        setState(() => _isAddingText = false);
                        _textInputCtrl.clear();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _addTextOverlay(_textInputCtrl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  Widget _glassButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ─── Text Overlay Model ───────────────────────────────────────────────────────

class _TextOverlay {
  String text;
  Offset position;
  double scale = 1.0;
  Color color = Colors.white;

  // Gesture tracking (survives setState rebuilds)
  double gestureBaseScale = 1.0;
  Offset gestureStartFocal = Offset.zero;
  Offset gestureStartPos = Offset.zero;

  _TextOverlay({required this.text, required this.position});
}
