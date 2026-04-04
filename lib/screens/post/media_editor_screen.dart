import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../utils/haptic_helper.dart';
import '../shared/music_picker_screen.dart';
import '../shared/music_editor_screen.dart';
import '../shared/post_settings_sheet.dart';
import '../shared/final_post_screen.dart';

// ─── Tool Modes ───────────────────────────────────────────────────────────────

enum _EditorTool { none, filter, adjust, text, overlay, edit }

// ─── Widget ───────────────────────────────────────────────────────────────────

class MediaEditorScreen extends StatefulWidget {
  final List<File> files;
  final String? initialCaption;

  const MediaEditorScreen({
    super.key,
    required this.files,
    this.initialCaption,
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
  double _contrast = 1.0;   // 0.5 to 1.5
  double _saturation = 1.0; // 0 to 2
  MusicTrack? _selectedMusic;

  // Text overlay
  final List<_TextOverlay> _overlays = [];
  bool _isAddingText = false;
  final TextEditingController _textInputCtrl = TextEditingController();

  late AnimationController _toolbarAnimCtrl;
  late Animation<double> _toolbarAnim;
  late AnimationController _sheetAnimCtrl;
  late Animation<Offset> _sheetSlide;

  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  int _trimStartSeconds = 0;

  // ── Filter definitions ────────────────────────────────────────────────────
  final List<String> _filterNames = [
    'Original', 'Vivid', 'Warm', 'Cool',
    'Noir', 'Fade', 'Chrome', 'Sepia', 'Cinematic', 'Cyber',
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
      sr + s * c, sg, sb, 0, bv,
      sr, sg + s * c, sb, 0, bv,
      sr, sg, sb + s * c, 0, bv,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _combineMatrices(List<double> a, List<double> b) {
    // Simple average blend for demo; real pipeline would multiply
    return List.generate(20, (i) => (a[i] + b[i]) / 2);
  }

  final List<List<double>> _filterMatrices = [
    // Original
    [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
    // Vivid
    [1.3,0,0,0,0, 0,1.3,0,0,0, 0,0,1.2,0,0, 0,0,0,1,0],
    // Warm
    [1.2,0,0,0,10, 0,1.1,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0],
    // Cool
    [0.9,0,0.1,0,0, 0,1.0,0.1,0,0, 0.1,0,1.2,0,10, 0,0,0,1,0],
    // Noir
    [0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0,0,0,1,0],
    // Fade
    [1,0,0,0,20, 0,1,0,0,20, 0,0,1,0,20, 0,0,0,0.85,0],
    // Chrome
    [1.3,0.1,0,0,0, 0,1.1,0.1,0,0, 0,0,1.2,0,0, 0,0,0,1,0],
    // Sepia
    [0.39,0.77,0.19,0,0, 0.35,0.69,0.17,0,0, 0.27,0.53,0.13,0,0, 0,0,0,1,0],
    // Cinematic
    [1.3,0.1,0,0,10, 0,1.1,0.1,0,5, 0,0.2,1.3,0,20, 0,0,0,1,0],
    // Cyber
    [1.2,0,0.5,0,10, 0,0.8,0.5,0,0, 0.5,0,1.2,0,20, 0,0,0,1,0],
  ];

  // ── Colors per filter ─────────────────────────────────────────────────────
  final List<Color> _filterAccents = [
    Colors.white, const Color(0xFFFF6B6B), const Color(0xFFFFBE0B),
    const Color(0xFF60A5FA), Colors.grey, const Color(0xFFD4D4D4),
    const Color(0xFFC084FC), const Color(0xFFB45309), const Color(0xFF1D4ED8),
    const Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();

    _toolbarAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _toolbarAnim = CurvedAnimation(parent: _toolbarAnimCtrl, curve: Curves.easeOut);
    _toolbarAnimCtrl.forward();

    _sheetAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetAnimCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _toolbarAnimCtrl.dispose();
    _sheetAnimCtrl.dispose();
    _textInputCtrl.dispose();
    _bgAudioPlayer.dispose();
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

  Future<void> _onNext() async {
    KnockHaptics.tap();
    final settings = await showPostSettingsSheet(context, isGlimpse: false);
    if (settings == null || !mounted) return;
    
    await _bgAudioPlayer.stop();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FinalPostScreen(
          files: widget.files,
          initialCaption: widget.initialCaption,
          isGlimpse: false,
          selectedDuration: settings.duration,
          selectedAudience: settings.audience,
          initialMusic: _selectedMusic,
          initialTrimSeconds: _trimStartSeconds,
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
      final isVideo = widget.files.isNotEmpty &&
          (widget.files.first.path.toLowerCase().endsWith('.mp4') ||
           widget.files.first.path.toLowerCase().endsWith('.mov'));

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

      if (overlayResult != null && overlayResult is Map && mounted) {
        setState(() {
          _selectedMusic = overlayResult['track'] as MusicTrack;
          _trimStartSeconds = overlayResult['trimStartSeconds'] as int;
          _activeTool = _EditorTool.none;
        });
        _sheetAnimCtrl.reverse();
        _playSelectedMusic();
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
      _overlays.add(_TextOverlay(
        text: text.trim(),
        position: Offset(size.width / 2 - 80, size.height / 2 - 100),
      ));
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Image with ColorFilter ─────────────────────────────────
          ColorFiltered(
            colorFilter: ColorFilter.matrix(_activeMatrix),
            child: Image.file(
              file,
              width: size.width,
              height: size.height,
              fit: BoxFit.contain,
            ),
          ),

          // ── 2. Top gradient ──────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0, height: 140,
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
            bottom: 0, left: 0, right: 0, height: 300,
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

          // ── 4. Text overlays (draggable) ─────────────────────────────
          ..._overlays.map((ov) => Positioned(
            left: ov.position.dx,
            top: ov.position.dy,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() => ov.position += d.delta),
              onDoubleTap: () => setState(() => _overlays.remove(ov)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  ov.text,
                  style: TextStyle(
                    color: ov.color,
                    fontSize: 28 * ov.scale,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
                  ),
                ),
              ),
            ),
          )),

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
                          child: Image.file(widget.files[i], fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

          // ── 6. Music chip ─────────────────────────────────────────────
          if (_selectedMusic != null && !_isAddingText)
            Positioned(
              bottom: 200,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_note_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedMusic!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _selectedMusic!.artist,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            KnockHaptics.tap();
                            setState(() {
                              _selectedMusic = null;
                            });
                            _bgAudioPlayer.stop();
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  FadeTransition(opacity: _toolbarAnim, child: _buildBottomBar()),
                  const SizedBox(height: 8),
                ],
              ),
            ),

          // ── 8. Full-screen text input overlay ────────────────────────
          if (_isAddingText) _buildTextInputOverlay(size),
        ],
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
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          // Label pill
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
            onTap: _onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
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
                  _toolBtn(Icons.layers_rounded, 'Overlay',
                      _EditorTool.overlay, const Color(0xFFE879F9)),
                  const SizedBox(width: 12),
                  _toolBtn(Icons.crop_rotate_rounded, 'Edit',
                      _EditorTool.edit, const Color(0xFFF472B6)),
                  const SizedBox(width: 12),
                  _toolBtn(Icons.auto_awesome_rounded, 'Filter',
                      _EditorTool.filter, const Color(0xFFFBBF24)),
                  const SizedBox(width: 12),
                  _toolBtn(Icons.tune_rounded, 'Adjust',
                      _EditorTool.adjust, const Color(0xFF60A5FA)),
                  const SizedBox(width: 12),
                  _toolBtn(Icons.text_fields_rounded, 'Text',
                      _EditorTool.text, const Color(0xFF34D399)),
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

  Widget _toolBtn(IconData icon, String label, _EditorTool tool, Color accent) {
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
              ? accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? accent.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22,
                color: isActive ? accent : Colors.white.withValues(alpha: 0.75)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? accent : Colors.white.withValues(alpha: 0.55),
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
    const accent = Color(0xFFA855F7);
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        _pickMusic();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasMusic ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasMusic ? accent.withValues(alpha: 0.45) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasMusic ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
              size: 22,
              color: hasMusic ? accent : Colors.white.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 4),
            Text(
              hasMusic ? 'Music ✓' : 'Music',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: hasMusic ? accent : Colors.white.withValues(alpha: 0.55),
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
      child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
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
          final accent = _filterAccents[i];
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
                        color: isSelected ? accent : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 10)]
                          : [],
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
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? accent : Colors.white60,
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
            label: 'Brightness', icon: Icons.brightness_6_rounded,
            value: (_brightness + 1) / 2,
            accent: const Color(0xFFFBBF24),
            onChanged: (v) => setState(() => _brightness = v * 2 - 1),
          ),
          const SizedBox(height: 14),
          _buildSlider(
            label: 'Contrast', icon: Icons.contrast_rounded,
            value: (_contrast - 0.5) / 1.0,
            accent: const Color(0xFF60A5FA),
            onChanged: (v) => setState(() => _contrast = v + 0.5),
          ),
          const SizedBox(height: 14),
          _buildSlider(
            label: 'Saturation', icon: Icons.palette_rounded,
            value: _saturation / 2,
            accent: const Color(0xFF34D399),
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
    required Color accent,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              overlayColor: accent.withValues(alpha: 0.2),
            ),
            child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
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
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _addTextOverlay(_textInputCtrl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
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

  _TextOverlay({
    required this.text,
    required this.position,
  });
}
