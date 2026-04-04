import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:io';

/// Instagram-quality pinch-to-zoom.
///
/// Uses a raw [Listener] to track pointer positions manually — NO GestureDetector,
/// NO gesture arena, NO conflict with PageView. Scale is computed directly from
/// the distance between two fingers on every PointerMoveEvent.
class KnockZoomer extends StatefulWidget {
  final String? imagePath;
  final String? networkUrl;
  final BoxFit fit;

  const KnockZoomer({
    super.key,
    this.imagePath,
    this.networkUrl,
    this.fit = BoxFit.cover,
  }) : assert(
          imagePath != null || networkUrl != null,
          'Provide either imagePath or networkUrl.',
        );

  @override
  State<KnockZoomer> createState() => _KnockZoomerState();
}

class _KnockZoomerState extends State<KnockZoomer>
    with SingleTickerProviderStateMixin {
  // ── Constants (tune here) ─────────────────────────────────────────────────
  static const double _maxScale   = 2.5;   // ceiling before rubber-band
  static const double _minScale   = 1.0;   // hard floor — never shrink below original
  static const double _minSpan    = 10.0;  // ignore micro pinches
  static const double _amplify    = 1.8;   // less spread needed to zoom
  static const double _rubberCoef = 0.20;  // elastic resistance at top limit

  // ── Safety ────────────────────────────────────────────────────────────────
  bool _disposed = false;

  // ── Raw pointer tracking (bypasses gesture arena entirely) ────────────────
  final Map<int, Offset> _pts = {}; // pointerId → current screen position
  double _startSpan  = 0.0;        // finger distance at pinch start
  double _baseScale  = 1.0;        // _scale at pinch start
  Offset _lastFocal  = Offset.zero; // midpoint on previous frame

  // ── Zoom state ────────────────────────────────────────────────────────────
  double _scale     = 1.0;
  Offset _pan       = Offset.zero;
  Offset _localFocal = Offset.zero; // Transform pivot (image-local coords)

  // ── Overlay ───────────────────────────────────────────────────────────────
  OverlayEntry? _overlay;
  Offset _originGlobal = Offset.zero;
  Size   _imageSize    = Size.zero;

  // ── Notifiers (hot-path updates without setState) ─────────────────────────
  late final ValueNotifier<Matrix4> _matrix;
  late final ValueNotifier<double>  _darkness;
  late final ValueNotifier<double>  _srcOpacity;

  // ── Snap-back animation ───────────────────────────────────────────────────
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  double _animStartScale = 1.0;
  Offset _animStartPan   = Offset.zero;

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _matrix     = ValueNotifier(Matrix4.identity());
    _darkness   = ValueNotifier(0.0);
    _srcOpacity = ValueNotifier(1.0);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo);
    _ctrl.addListener(_onTick);
    _ctrl.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _disposed = true;
    _ctrl
      ..removeListener(_onTick)
      ..removeStatusListener(_onStatus)
      ..dispose();
    _cleanOverlay();
    _matrix.dispose();
    _darkness.dispose();
    _srcOpacity.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Math
  // ══════════════════════════════════════════════════════════════════════════

  Matrix4 _mk(double s, Offset p) =>
      Matrix4.translationValues(p.dx, p.dy, 0)
        ..multiply(Matrix4.diagonal3Values(s, s, 1));

  double _dark(double s) =>
      ((s - 1.0) / (_maxScale - 1.0) * 0.50).clamp(0.0, 0.50);

  // Rubber-band at the top only — clamp hard at 1.0 on the low end
  double _rubberBand(double raw) {
    if (raw <= _minScale) return _minScale;  // hard floor
    if (raw <= _maxScale) return raw;
    final excess = raw - _maxScale;
    return _maxScale + excess * _rubberCoef / (1.0 + excess * 0.30);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Animation
  // ══════════════════════════════════════════════════════════════════════════

  void _onTick() {
    if (_disposed || _ctrl.status != AnimationStatus.forward) return;
    final t = _anim.value;
    final s = lerpDouble(_animStartScale, 1.0, t)!;
    final p = Offset.lerp(_animStartPan, Offset.zero, t)!;
    _matrix.value   = _mk(s, p);
    _darkness.value = _dark(s);
  }

  void _onStatus(AnimationStatus status) {
    if (_disposed || status != AnimationStatus.completed) return;
    _cleanOverlay();
    _srcOpacity.value = 1.0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Overlay
  // ══════════════════════════════════════════════════════════════════════════

  bool _resolveBox() {
    final ro = context.findRenderObject();
    if (ro == null || !ro.attached || ro is! RenderBox) return false;
    _originGlobal = ro.localToGlobal(Offset.zero);
    _imageSize    = ro.size;
    return true;
  }

  void _showOverlay(Offset globalFocal) {
    if (_disposed || _overlay != null || !mounted) return;
    if (!_resolveBox()) return;

    final ro = context.findRenderObject() as RenderBox;
    _localFocal     = ro.globalToLocal(globalFocal);
    _matrix.value   = _mk(_scale, _pan);
    _darkness.value = _dark(_scale);

    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlay!);
    _srcOpacity.value = 0.0;
  }

  void _cleanOverlay() {
    if (_overlay == null) return;
    try { if (_overlay!.mounted) _overlay!.remove(); } catch (_) {}
    _overlay        = null;
    _scale          = 1.0;
    _baseScale      = 1.0;
    _pan            = Offset.zero;
    _animStartScale = 1.0;
    _animStartPan   = Offset.zero;
  }

  Widget _buildOverlay(BuildContext _) => Stack(
    children: [
      // ── Scrim: absorbs scroll/drag gestures so feed doesn't scroll ───────
      Positioned.fill(
        child: GestureDetector(
          // HitTestBehavior.opaque: this becomes the gesture target, not the feed
          behavior: HitTestBehavior.opaque,
          // Register pan handler so scroll recognizer can't win the arena
          onPanUpdate: (_) {},
          onPanStart:  (_) {},
          onPanEnd:    (_) {},
          child: ValueListenableBuilder<double>(
            valueListenable: _darkness,
            builder: (_, d, __) => ColoredBox(
              color: Colors.black.withOpacity(d),
            ),
          ),
        ),
      ),
      // ── Zoomed image ─────────────────────────────────────────────────────
      ValueListenableBuilder<Matrix4>(
        valueListenable: _matrix,
        builder: (_, mat, __) => Positioned(
          left:   _originGlobal.dx,
          top:    _originGlobal.dy,
          width:  _imageSize.width,
          height: _imageSize.height,
          child: IgnorePointer(
            child: Transform(
              transform: mat,
              alignment: null,
              origin:    _localFocal,
              child: _img(),
            ),
          ),
        ),
      ),
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Raw pointer tracking — no gesture arena, always fires
  // ══════════════════════════════════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent e) {
    if (_disposed) return;
    _pts[e.pointer] = e.position;

    if (_pts.length == 2) {
      // Stop any ongoing snap-back and capture current state as new base
      if (_ctrl.isAnimating) _ctrl.stop();
      _baseScale = _scale;

      final positions = _pts.values.toList();
      _startSpan = _span(positions[0], positions[1]);
      _lastFocal = _mid(positions[0], positions[1]);

      _showOverlay(_lastFocal);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_disposed) return;
    if (!_pts.containsKey(e.pointer)) return;
    _pts[e.pointer] = e.position;

    // Only handle when exactly 2 fingers are active and overlay is showing
    if (_pts.length < 2 || _overlay == null) return;
    if (_ctrl.isAnimating) return;

    final positions = _pts.values.toList();
    final currentSpan  = _span(positions[0], positions[1]);
    final currentFocal = _mid(positions[0], positions[1]);

    // ── Pan: image follows finger midpoint ──────────────────────────────────
    _pan += currentFocal - _lastFocal;
    _lastFocal = currentFocal;

    // ── Scale: amplified ratio of finger distance change ────────────────────
    if (_startSpan > _minSpan) {
      final ratio     = currentSpan / _startSpan;
      final amplified = 1.0 + (ratio - 1.0) * _amplify;
      _scale = _rubberBand(_baseScale * amplified);
    }

    _matrix.value   = _mk(_scale, _pan);
    _darkness.value = _dark(_scale);

    // Auto-dismiss when pinching back to 1.0 — no animation needed at this point
    if (_scale <= 1.0 && _pan.distance < 30 && !_ctrl.isAnimating) {
      _cleanOverlay();
      _srcOpacity.value = 1.0;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_disposed) return;
    _pts.remove(e.pointer);
    _maybeSnapBack();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (_disposed) return;
    _pts.remove(e.pointer);
    _maybeSnapBack();
  }

  void _maybeSnapBack() {
    if (_pts.length < 2 && _overlay != null && !_ctrl.isAnimating) {
      _animStartScale = _scale;
      _animStartPan   = _pan;
      _ctrl.forward(from: 0);
    }
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────
  static double  _span(Offset a, Offset b) => (a - b).distance;
  static Offset  _mid(Offset a, Offset b)  => Offset(
    (a.dx + b.dx) / 2,
    (a.dy + b.dy) / 2,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Image
  // ══════════════════════════════════════════════════════════════════════════

  Widget _img() {
    if (widget.networkUrl != null) {
      return Image.network(
        widget.networkUrl!,
        fit: widget.fit,
        filterQuality: FilterQuality.high,
      );
    }

    if (widget.imagePath != null &&
        (widget.imagePath!.startsWith('/') ||
         widget.imagePath!.startsWith('file://') ||
         widget.imagePath!.startsWith('C:') ||
         widget.imagePath!.contains('/data/user/'))) {
      return Image.file(
        File(widget.imagePath!),
        fit: widget.fit,
        filterQuality: FilterQuality.high,
      );
    }

    return Image.asset(
      widget.imagePath!,
      fit: widget.fit,
      filterQuality: FilterQuality.high,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Listener(
      // HitTestBehavior.translucent: lets single-finger events pass through
      // to the PageView while still receiving our multi-finger events.
      behavior: HitTestBehavior.translucent,
      onPointerDown:   _onPointerDown,
      onPointerMove:   _onPointerMove,
      onPointerUp:     _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ValueListenableBuilder<double>(
        valueListenable: _srcOpacity,
        builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
        child: _img(),
      ),
    );
  }
}
