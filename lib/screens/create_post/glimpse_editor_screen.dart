import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../utils/haptic_helper.dart';
import '../../models/post_model.dart';
import 'music_picker_screen.dart';
import 'music_editor_screen.dart';
import 'post_settings_sheet.dart';

class GlimpseEditorScreen extends StatefulWidget {
  final List<File> files;
  final String? initialCaption;
  final double playbackSpeed;

  const GlimpseEditorScreen({
    super.key,
    required this.files,
    this.initialCaption,
    this.playbackSpeed = 1.0,
  });

  @override
  State<GlimpseEditorScreen> createState() => _GlimpseEditorScreenState();
}

class _TextOverlay {
  String text;
  Offset position;
  double scale;
  Color color;

  _TextOverlay({
    required this.text,
    required this.position,
    this.scale = 1.0,
    this.color = Colors.white,
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

class _GlimpseEditorScreenState extends State<GlimpseEditorScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _captionController;
  MusicTrack? _selectedMusic;
  int _selectedFilterIndex = 0;
  int _currentMediaIndex = 0;
  bool _showFilters = false;

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

  final List<String> _filterNames = [
    "Original",
    "Warm",
    "Cool",
    "Vintage",
    "Noir",
    "Fade",
    "Cyber",
    "Cinematic",
    "Film",
    "Sepia",
  ];
  final List<List<double>> _filterMatrices = [
    [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0], // Original
    [1.2, 0, 0, 0, 10, 0, 1.1, 0, 0, 5, 0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0], // Warm
    [
      0.9,
      0,
      0.1,
      0,
      0,
      0,
      1.0,
      0.1,
      0,
      0,
      0.1,
      0,
      1.2,
      0,
      10,
      0,
      0,
      0,
      1,
      0,
    ], // Cool
    [
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
    ], // Vintage
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
    ], // Noir
    [1, 0, 0, 0, 20, 0, 1, 0, 0, 20, 0, 0, 1, 0, 20, 0, 0, 0, 0.85, 0], // Fade
    [
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
    ], // Cyber
    [
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
    ], // Cinematic
    [
      1.05,
      0.05,
      0.05,
      0,
      8,
      0.05,
      1.0,
      0.05,
      0,
      5,
      0.05,
      0.05,
      0.95,
      0,
      3,
      0,
      0,
      0,
      1,
      0,
    ], // Film
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
    ], // Sepia
  ];

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(
      text: widget.initialCaption ?? "",
    );
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
      if (pathLower.endsWith('.mp4') ||
          pathLower.endsWith('.mov') ||
          pathLower.endsWith('.mkv')) {
        final ctrl = VideoPlayerController.file(file);
        ctrl.initialize().then((_) async {
          if (mounted) setState(() {});
          await ctrl.setPlaybackSpeed(widget.playbackSpeed);
          await ctrl.setLooping(true);
          // Auto-play first video
          if (i == 0) await ctrl.play();
        });
        return ctrl;
      }
      return null;
    });
  }

  @override
  void dispose() {
    for (var ctrl in _videoControllers) {
      ctrl?.dispose();
    }
    _captionController.dispose();
    _textOverlayController.dispose();
    _textFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _publishGlimpse() async {
    KnockHaptics.tap();
    final settings = await showPostSettingsSheet(
      context,
      isGlimpse: true,
    );
    if (settings == null || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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

          // ─── 2. DRAWING LAYER ───
          if (_drawPaths.isNotEmpty ||
              _currentDrawPath != null ||
              _isDrawingMode)
            _buildDrawingLayer(),

          // ─── 3. TEXT & STICKER OVERLAYS ───
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
                                      _filterNames[_selectedFilterIndex],
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

                    if (_selectedMusic != null && !_isDrawingMode)
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
                    const Text(
                      "GLIMPSE",
                      style: TextStyle(
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
                        // Open new MusicOverlayScreen
                        final isVideo =
                            _videoControllers[_currentMediaIndex] != null;
                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (_, __, ___) => MusicOverlayScreen(
                              track: result,
                              isVideo: isVideo,
                            ),
                          ),
                        );
                        // Once finished with overlay, set active music
                        setState(() => _selectedMusic = result);
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
              if (_selectedMusic != null) {
                // Capped to 15 seconds if music is present
                // Additional actual trimming logic would go here
              }
            } else {
              _videoControllers[j]!.pause();
            }
          }
        }
      },
      itemBuilder: (context, i) {
        final vCtrl = _videoControllers[i];
        final isVideo = vCtrl != null;

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Container(
            color: Colors.black,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(
                _filterMatrices[_selectedFilterIndex]
                    .map((e) => e.toDouble())
                    .toList(),
              ),
              child: isVideo
                  ? (vCtrl.value.isInitialized
                        ? Center(
                            child: AspectRatio(
                              aspectRatio: vCtrl.value.aspectRatio,
                              child: VideoPlayer(vCtrl),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ))
                  : Image.file(widget.files[i], fit: BoxFit.cover),
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
        itemCount: _filterNames.length,
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
                              colorFilter: ColorFilter.matrix(
                                _filterMatrices[i]
                                    .map((e) => e.toDouble())
                                    .toList(),
                              ),
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
                    _filterNames[i],
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
            onTap: _publishGlimpse,
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
                  const Text(
                    "Post Glimpse",
                    style: TextStyle(
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
