import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/haptic_helper.dart';
import 'media_editor_screen.dart';
import '../waves/waves_editor_screen.dart';

// ─── Collage Layout Definitions ───────────────────────────────────────────────

class _LayoutDef {
  final String name;
  final int photoCount;
  final List<Rect> slots;

  const _LayoutDef({
    required this.name,
    required this.photoCount,
    required this.slots,
  });
}

// Layouts optimized for tall portrait (9:16) canvas — like Instagram stories collage.
// Uses horizontal rows as primary split to keep cells well-proportioned.
final Map<int, List<_LayoutDef>> _layoutsByCount = {
  2: [
    // Top-bottom: two equal rows
    const _LayoutDef(name: 'Stack', photoCount: 2, slots: [
      Rect.fromLTWH(0, 0, 1, 0.5),
      Rect.fromLTWH(0, 0.5, 1, 0.5),
    ]),
    // Big top (65%) + small bottom (35%)
    const _LayoutDef(name: 'Hero', photoCount: 2, slots: [
      Rect.fromLTWH(0, 0, 1, 0.65),
      Rect.fromLTWH(0, 0.65, 1, 0.35),
    ]),
    // Side by side columns
    const _LayoutDef(name: 'Side', photoCount: 2, slots: [
      Rect.fromLTWH(0, 0, 0.5, 1),
      Rect.fromLTWH(0.5, 0, 0.5, 1),
    ]),
  ],
  3: [
    // 1 big top (55%) + 2 side-by-side bottom (45%)
    const _LayoutDef(name: '1+2', photoCount: 3, slots: [
      Rect.fromLTWH(0, 0, 1, 0.55),
      Rect.fromLTWH(0, 0.55, 0.5, 0.45),
      Rect.fromLTWH(0.5, 0.55, 0.5, 0.45),
    ]),
    // 2 side-by-side top (45%) + 1 big bottom (55%)
    const _LayoutDef(name: '2+1', photoCount: 3, slots: [
      Rect.fromLTWH(0, 0, 0.5, 0.45),
      Rect.fromLTWH(0.5, 0, 0.5, 0.45),
      Rect.fromLTWH(0, 0.45, 1, 0.55),
    ]),
    // 3 equal rows
    const _LayoutDef(name: 'Rows', photoCount: 3, slots: [
      Rect.fromLTWH(0, 0, 1, 0.3333),
      Rect.fromLTWH(0, 0.3333, 1, 0.3334),
      Rect.fromLTWH(0, 0.6667, 1, 0.3333),
    ]),
  ],
  4: [
    // 2×2 grid
    const _LayoutDef(name: 'Grid', photoCount: 4, slots: [
      Rect.fromLTWH(0, 0, 0.5, 0.5),
      Rect.fromLTWH(0.5, 0, 0.5, 0.5),
      Rect.fromLTWH(0, 0.5, 0.5, 0.5),
      Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
    ]),
    // 1 big top (50%) + 3 bottom row (50%)
    const _LayoutDef(name: '1+3', photoCount: 4, slots: [
      Rect.fromLTWH(0, 0, 1, 0.5),
      Rect.fromLTWH(0, 0.5, 0.3333, 0.5),
      Rect.fromLTWH(0.3333, 0.5, 0.3334, 0.5),
      Rect.fromLTWH(0.6667, 0.5, 0.3333, 0.5),
    ]),
    // 3 top row (40%) + 1 big bottom (60%)
    const _LayoutDef(name: '3+1', photoCount: 4, slots: [
      Rect.fromLTWH(0, 0, 0.3333, 0.4),
      Rect.fromLTWH(0.3333, 0, 0.3334, 0.4),
      Rect.fromLTWH(0.6667, 0, 0.3333, 0.4),
      Rect.fromLTWH(0, 0.4, 1, 0.6),
    ]),
  ],
  5: [
    // 2 top (50%) + 3 bottom (50%)
    const _LayoutDef(name: '2+3', photoCount: 5, slots: [
      Rect.fromLTWH(0, 0, 0.5, 0.5),
      Rect.fromLTWH(0.5, 0, 0.5, 0.5),
      Rect.fromLTWH(0, 0.5, 0.3333, 0.5),
      Rect.fromLTWH(0.3333, 0.5, 0.3334, 0.5),
      Rect.fromLTWH(0.6667, 0.5, 0.3333, 0.5),
    ]),
    // 3 top (40%) + 2 bottom (60%)
    const _LayoutDef(name: '3+2', photoCount: 5, slots: [
      Rect.fromLTWH(0, 0, 0.3333, 0.4),
      Rect.fromLTWH(0.3333, 0, 0.3334, 0.4),
      Rect.fromLTWH(0.6667, 0, 0.3333, 0.4),
      Rect.fromLTWH(0, 0.4, 0.5, 0.6),
      Rect.fromLTWH(0.5, 0.4, 0.5, 0.6),
    ]),
  ],
  6: [
    // 2×3 grid (2 cols × 3 rows)
    const _LayoutDef(name: 'Grid', photoCount: 6, slots: [
      Rect.fromLTWH(0, 0, 0.5, 0.3333),
      Rect.fromLTWH(0.5, 0, 0.5, 0.3333),
      Rect.fromLTWH(0, 0.3333, 0.5, 0.3334),
      Rect.fromLTWH(0.5, 0.3333, 0.5, 0.3334),
      Rect.fromLTWH(0, 0.6667, 0.5, 0.3333),
      Rect.fromLTWH(0.5, 0.6667, 0.5, 0.3333),
    ]),
    // 3×2 grid (3 cols × 2 rows)
    const _LayoutDef(name: 'Wide', photoCount: 6, slots: [
      Rect.fromLTWH(0, 0, 0.3333, 0.5),
      Rect.fromLTWH(0.3333, 0, 0.3334, 0.5),
      Rect.fromLTWH(0.6667, 0, 0.3333, 0.5),
      Rect.fromLTWH(0, 0.5, 0.3333, 0.5),
      Rect.fromLTWH(0.3333, 0.5, 0.3334, 0.5),
      Rect.fromLTWH(0.6667, 0.5, 0.3333, 0.5),
    ]),
  ],
};

// ═════════════════════════════════════════════════════════════════════════════
//  COLLAGE PICKER — Single screen: pick photos → edit collage → next
// ═════════════════════════════════════════════════════════════════════════════

class CollagePickerScreen extends StatefulWidget {
  final bool isGlimpse;
  const CollagePickerScreen({super.key, this.isGlimpse = true});

  @override
  State<CollagePickerScreen> createState() => _CollagePickerScreenState();
}

class _CollagePickerScreenState extends State<CollagePickerScreen> {
  // ── Gallery state ──
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  final List<AssetEntity> _selected = [];

  // ── Editor state (visible after photos picked) ──
  bool _inEditor = false;
  List<File> _files = [];
  int _layoutIndex = 0;
  double _spacing = 3.0;
  int _bgIndex = 0;
  bool _isExporting = false;

  final GlobalKey _collageKey = GlobalKey();

  static const _bgColors = [
    Colors.white,
    Colors.black,
    Color(0xFF1C1C1E),
    Color(0xFF2C2C2E),
    Color(0xFF3A3A3C),
  ];

  @override
  void initState() {
    super.initState();
    _fetchGallery();
  }

  Future<void> _fetchGallery() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    AssetPathEntity? allAlbum;
    for (var a in albums) {
      if (a.isAll) { allAlbum = a; break; }
    }
    allAlbum ??= albums.isNotEmpty ? albums.first : null;

    if (allAlbum != null) {
      final assets = await allAlbum.getAssetListPaged(page: 0, size: 500);
      if (mounted) setState(() { _assets = assets; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _tap(AssetEntity asset) {
    KnockHaptics.tap();
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else if (_selected.length < 6) {
        _selected.add(asset);
      }
    });
  }

  List<_LayoutDef> get _availableLayouts {
    final n = _files.length;
    return _layoutsByCount[n] ?? [];
  }

  Future<void> _goToEditor() async {
    if (_selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least 2 photos'),
          backgroundColor: Color(0xFF333333),
        ),
      );
      return;
    }
    KnockHaptics.tap();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5,
                ),
              ),
              SizedBox(height: 14),
              Text('Preparing...', style: TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
      ),
    );

    List<File> files = [];
    for (var a in _selected) {
      final f = await a.file;
      if (f != null) files.add(f);
    }

    if (mounted) {
      Navigator.pop(context);
      setState(() {
        _files = files;
        _inEditor = true;
        _layoutIndex = 0;
      });
    }
  }

  Future<void> _export() async {
    if (_isExporting) return;
    KnockHaptics.tap();
    setState(() => _isExporting = true);

    try {
      final boundary = _collageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/collage_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        setState(() => _isExporting = false);
        if (widget.isGlimpse) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => WavesEditorScreen(files: [file]),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MediaEditorScreen(files: [file], initialCaption: ''),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Collage export error: $e');
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(child: _inEditor ? _buildEditor() : _buildPicker()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PICKER VIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPicker() {
    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'Collage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_selected.length}/6',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _selected.length >= 2 ? _goToEditor : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selected.length >= 2 ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: _selected.length >= 2 ? Colors.black : Colors.white30,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Selected strip ──
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _selected.length,
              itemBuilder: (_, i) {
                final asset = _selected[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      KnockHaptics.tap();
                      setState(() => _selected.remove(asset));
                    },
                    child: Stack(
                      children: [
                        FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(const ThumbnailSize.square(150)),
                          builder: (_, snap) {
                            if (snap.hasData && snap.data != null) {
                              return Container(
                                width: 62, height: 62,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.5),
                                  child: Image.memory(snap.data!, fit: BoxFit.cover),
                                ),
                              );
                            }
                            return Container(
                              width: 62, height: 62,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: -2, right: -2,
                          child: Container(
                            width: 22, height: 22,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

        const SizedBox(height: 6),

        // ── Recents label ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Recents',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
            ],
          ),
        ),

        // ── Gallery grid ──
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : _assets.isEmpty
                  ? const Center(child: Text('No photos found', style: TextStyle(color: Colors.white30)))
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(1),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 1.5,
                        mainAxisSpacing: 1.5,
                      ),
                      itemCount: _assets.length,
                      itemBuilder: (context, index) {
                        final asset = _assets[index];
                        final isSelected = _selected.contains(asset);
                        final selIdx = _selected.indexOf(asset) + 1;
                        final isFull = _selected.length >= 6;

                        return GestureDetector(
                          onTap: () => _tap(asset),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
                                builder: (_, snap) {
                                  if (snap.hasData && snap.data != null) {
                                    return Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true);
                                  }
                                  return Container(color: Colors.white.withValues(alpha: 0.05));
                                },
                              ),
                              if (isFull && !isSelected)
                                Container(color: Colors.black.withValues(alpha: 0.55)),
                              if (isSelected)
                                Container(color: Colors.white.withValues(alpha: 0.15)),
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? Colors.white : Colors.black38,
                                    border: Border.all(color: Colors.white, width: isSelected ? 0 : 1.5),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Text(
                                            '$selIdx',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EDITOR VIEW — Full screen immersive (Instagram-style)
  // ─────────────────────────────────────────────────────────────────────────

  List<TransformationController> _transformControllers = [];

  void _ensureControllers() {
    if (_transformControllers.length != _files.length) {
      for (var c in _transformControllers) { c.dispose(); }
      _transformControllers = List.generate(
        _files.length,
        (_) => TransformationController(),
      );
    }
  }

  Widget _buildEditor() {
    _ensureControllers();
    final layouts = _availableLayouts;
    if (layouts.isEmpty) {
      return const Center(
        child: Text('Unsupported photo count', style: TextStyle(color: Colors.white54)),
      );
    }
    final currentLayout = layouts[_layoutIndex.clamp(0, layouts.length - 1)];

    return Stack(
      children: [
        // ── 1. COLLAGE CANVAS (Background) ──
        Align(
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: RepaintBoundary(
              key: _collageKey,
              child: Container(
                color: _bgColors[_bgIndex],
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final g = _spacing / 2;
                    return Stack(
                      children: List.generate(
                        _files.length.clamp(0, currentLayout.slots.length),
                        (i) {
                          final r = currentLayout.slots[i];
                          final left = r.left * w + g;
                          final top = r.top * h + g;
                          final cellW = (r.width * w - _spacing).clamp(1.0, w);
                          final cellH = (r.height * h - _spacing).clamp(1.0, h);
                          return Positioned(
                            left: left,
                            top: top,
                            width: cellW,
                            height: cellH,
                            child: ClipRect(
                              child: InteractiveViewer(
                                transformationController: _transformControllers[i],
                                minScale: 0.5,
                                maxScale: 4.0,
                                panEnabled: true,
                                scaleEnabled: true,
                                clipBehavior: Clip.none,
                                boundaryMargin: const EdgeInsets.all(double.infinity),
                                child: SizedBox(
                                  width: cellW,
                                  height: cellH,
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.none,
                                    child: Image.file(_files[i]),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // ── 2. TOP BAR (Foreground Overlay) ──
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16, right: 16, bottom: 12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    for (var c in _transformControllers) { c.dispose(); }
                    _transformControllers = [];
                    setState(() { _inEditor = false; _files.clear(); });
                  },
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _isExporting ? null : _export,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _isExporting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Next',
                            style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 3. BOTTOM TOOLS & LAYOUTS ──
        // ── 3. RIGHT SIDE TOOLS ──
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reset zoom
                    GestureDetector(
                      onTap: () {
                        KnockHaptics.tap();
                        for (var c in _transformControllers) {
                          c.value = Matrix4.identity();
                        }
                        setState(() {});
                      },
                      child: const Icon(Icons.crop_free_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 24),
                    // Gap cycle
                    GestureDetector(
                      onTap: () {
                        KnockHaptics.tap();
                        setState(() {
                          if (_spacing < 4) { _spacing = 4; }
                          else if (_spacing < 8) { _spacing = 8; }
                          else if (_spacing < 12) { _spacing = 12; }
                          else { _spacing = 0; }
                        });
                      },
                      child: const Icon(Icons.space_bar_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 24),
                    // BG Color cycle
                    GestureDetector(
                      onTap: () {
                        KnockHaptics.tap();
                        setState(() => _bgIndex = (_bgIndex + 1) % _bgColors.length);
                      },
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: _bgColors[_bgIndex],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

        // ── 4. BOTTOM LAYOUTS ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (layouts.length > 1)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    top: 8,
                  ),
                  child: Center(
                    child: SizedBox(
                      height: 56,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true, // Centers the layout items
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: layouts.length,
                        itemBuilder: (_, i) {
                          final isActive = i == _layoutIndex;
                          return GestureDetector(
                            onTap: () {
                              KnockHaptics.tap();
                              setState(() => _layoutIndex = i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52, height: 52,
                              margin: i == layouts.length - 1
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.only(right: 14),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: isActive ? 2 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: _MiniLayoutPreview(layout: layouts[i]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              else
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Mini layout thumbnail ───────────────────────────────────────────────────

class _MiniLayoutPreview extends StatelessWidget {
  final _LayoutDef layout;
  const _MiniLayoutPreview({required this.layout});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: List.generate(layout.slots.length, (i) {
            final r = layout.slots[i];
            return Positioned(
              left: r.left * w + 0.5,
              top: r.top * h + 0.5,
              width: (r.width * w - 1).clamp(0, w),
              height: (r.height * h - 1).clamp(0, h),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
