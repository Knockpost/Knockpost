import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'post_scroll_lock_scope.dart';

enum _ZoomGestureMode { idle, zoom, pan }

class ZoomablePostImage extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDoubleTap;
  final ValueChanged<bool>? onInteractionChanged;
  final double minScale;
  final double maxScale;
  final Duration resetDuration;

  const ZoomablePostImage({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.onInteractionChanged,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.resetDuration = const Duration(milliseconds: 220),
  });

  @override
  State<ZoomablePostImage> createState() => _ZoomablePostImageState();
}

class _ZoomablePostImageState extends State<ZoomablePostImage>
    with SingleTickerProviderStateMixin {
  static const double _identityEpsilon = 0.001;
  static const double _softClampResistance = 0.12;
  static const double _horizontalPanLimitFactor = 0.80;
  static const double _verticalPanLimitFactor = 0.44;
  static const double _maxHorizontalOverflow = 20.0;
  static const double _maxVerticalOverflow = 6.0;

  final Map<int, Offset> _activePointers = <int, Offset>{};
  final ValueNotifier<int> _overlayRefreshTick = ValueNotifier<int>(0);

  late final AnimationController _resetController;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _offsetAnimation;

  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _focalPoint = Offset.zero;
  double _previousScale = 1.0;
  Offset _previousOffset = Offset.zero;

  double _gestureStartSpan = 0.0;
  Offset _gestureStartFocalPoint = Offset.zero;
  _ZoomGestureMode _gestureMode = _ZoomGestureMode.idle;
  bool _interactionCaptured = false;
  bool _showInlineSource = true;

  Rect? _overlayRect;
  OverlayEntry? _overlayEntry;
  Size? _cachedViewportSize;

  PostScrollLockController? _scrollLockController;
  PostPageSwipeLockController? _pageSwipeLockController;

  @override
  void initState() {
    super.initState();
    _resetController =
        AnimationController(vsync: this, duration: widget.resetDuration)
          ..addListener(_handleResetTick)
          ..addStatusListener(_handleResetStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollLockController = PostScrollLockScope.maybeOf(context);
    _pageSwipeLockController = PostPageSwipeLockScope.maybeOf(context);
  }

  @override
  void dispose() {
    _endInteractionCapture();
    _removeOverlayPresentation();
    _overlayRefreshTick.dispose();
    _resetController
      ..removeListener(_handleResetTick)
      ..removeStatusListener(_handleResetStatusChanged)
      ..dispose();
    super.dispose();
  }

  Size get _viewportSize {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return Size.zero;
    }
    return renderBox.size;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;

    if (_activePointers.length >= 2) {
      _beginZoomGesture();
      return;
    }

    if (_scale > widget.minScale + _identityEpsilon) {
      _beginPanGesture();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;

    _activePointers[event.pointer] = event.localPosition;

    if (_activePointers.length >= 2) {
      if (_gestureMode != _ZoomGestureMode.zoom) {
        _beginZoomGesture();
      }
      _updateZoomGesture();
      return;
    }

    if (_activePointers.length == 1 &&
        _scale > widget.minScale + _identityEpsilon) {
      if (_gestureMode != _ZoomGestureMode.pan) {
        _beginPanGesture();
      }
      _updatePanGesture();
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);

    if (_activePointers.length >= 2) {
      _beginZoomGesture();
      return;
    }

    if (_activePointers.length == 1 &&
        _scale > widget.minScale + _identityEpsilon) {
      _beginPanGesture();
      return;
    }

    _finishInteraction();
  }

  void _beginZoomGesture() {
    if (_viewportSize == Size.zero) return;

    _stopResetAnimation();
    _ensureOverlayPresentation();
    _beginInteractionCapture();
    final metrics = _calculatePointerMetrics();

    _gestureMode = _ZoomGestureMode.zoom;
    _previousScale = _scale;
    _previousOffset = _offset;
    _gestureStartFocalPoint = _centeredPoint(metrics.centroid);
    _gestureStartSpan = math.max(metrics.span, 0.0001);
    _focalPoint = _gestureStartFocalPoint;
    _notifyOverlayPresentationChanged();
  }

  void _updateZoomGesture() {
    if (_viewportSize == Size.zero || _activePointers.length < 2) return;

    final metrics = _calculatePointerMetrics();
    _focalPoint = _centeredPoint(metrics.centroid);
    final currentSpan = math.max(metrics.span, 0.0001);
    final scaleFactor = currentSpan / _gestureStartSpan;
    final targetScale = _applyScaleResistance(_previousScale * scaleFactor);

    final targetOffset = _softClampOffset(
      _offsetForFocalLock(
        startScale: _previousScale,
        nextScale: targetScale,
        startOffset: _previousOffset,
        startFocalPoint: _gestureStartFocalPoint,
        currentFocalPoint: _focalPoint,
      ),
      targetScale,
      _viewportSize,
    );

    _scale = targetScale;
    _offset = targetOffset;
    _notifyOverlayPresentationChanged();
  }

  void _beginPanGesture() {
    if (_viewportSize == Size.zero || _activePointers.isEmpty) return;

    _stopResetAnimation();
    _ensureOverlayPresentation();
    _beginInteractionCapture();

    _gestureMode = _ZoomGestureMode.pan;
    _previousScale = _scale;
    _previousOffset = _offset;
    _gestureStartFocalPoint = _centeredPoint(_activePointers.values.first);
    _focalPoint = _gestureStartFocalPoint;
    _notifyOverlayPresentationChanged();
  }

  void _updatePanGesture() {
    if (_viewportSize == Size.zero || _activePointers.isEmpty) return;

    _focalPoint = _centeredPoint(_activePointers.values.first);
    final targetOffset = _softClampOffset(
      _offsetForFocalLock(
        startScale: _previousScale,
        nextScale: _scale,
        startOffset: _previousOffset,
        startFocalPoint: _gestureStartFocalPoint,
        currentFocalPoint: _focalPoint,
      ),
      _scale,
      _viewportSize,
    );

    _offset = targetOffset;
    _notifyOverlayPresentationChanged();
  }

  void _finishInteraction() {
    _activePointers.clear();
    _gestureMode = _ZoomGestureMode.idle;

    final shouldReset =
        (_scale - widget.minScale).abs() > _identityEpsilon ||
        _offset.distanceSquared > 0.001;

    if (!shouldReset) {
      _snapToIdentity();
      return;
    }

    final animation = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(
      begin: _scale,
      end: widget.minScale,
    ).animate(animation);
    _offsetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset.zero,
    ).animate(animation);

    _resetController.forward(from: 0);
  }

  void _handleResetTick() {
    final nextScale = _scaleAnimation?.value;
    final nextOffset = _offsetAnimation?.value;
    if (nextScale == null || nextOffset == null || !mounted) return;

    _scale = nextScale;
    _offset = nextOffset;
    _focalPoint = Offset.zero;
    _notifyOverlayPresentationChanged();
  }

  void _handleResetStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _snapToIdentity();
    }
  }

  void _snapToIdentity() {
    if (!mounted) return;

    setState(() {
      _scale = widget.minScale;
      _offset = Offset.zero;
      _focalPoint = Offset.zero;
      _previousScale = widget.minScale;
      _previousOffset = Offset.zero;
      _showInlineSource = true;
    });

    _removeOverlayPresentation();
    _endInteractionCapture();
  }

  void _stopResetAnimation() {
    if (!_resetController.isAnimating) return;

    _resetController.stop();
    _scale = _scaleAnimation?.value ?? _scale;
    _offset = _offsetAnimation?.value ?? _offset;
    _notifyOverlayPresentationChanged();
  }

  void _beginInteractionCapture() {
    if (_interactionCaptured) return;

    _interactionCaptured = true;
    widget.onInteractionChanged?.call(true);
    _scrollLockController?.lock();
    _pageSwipeLockController?.lock();
  }

  void _endInteractionCapture() {
    if (!_interactionCaptured) return;

    _interactionCaptured = false;
    widget.onInteractionChanged?.call(false);
    _scrollLockController?.unlock();
    _pageSwipeLockController?.unlock();
  }

  void _ensureOverlayPresentation() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;

    if (renderBox == null ||
        overlayBox == null ||
        !renderBox.hasSize ||
        !overlayBox.hasSize) {
      return;
    }

    _cachedViewportSize = renderBox.size;

    final topLeft = overlayBox.globalToLocal(
      renderBox.localToGlobal(Offset.zero),
    );
    _overlayRect = topLeft & renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return SizedBox.expand(
          child: ValueListenableBuilder<int>(
            valueListenable: _overlayRefreshTick,
            child: RepaintBoundary(child: widget.child),
            builder: (context, _, child) {
              final rect = _overlayRect;
              if (rect == null) {
                return const SizedBox.shrink();
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: IgnorePointer(
                      child: _buildTransformedPresentationChild(child),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    if (_showInlineSource) {
      setState(() {
        _showInlineSource = false;
      });
    }
    _notifyOverlayPresentationChanged();
  }

  void _removeOverlayPresentation() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayRect = null;
  }

  void _notifyOverlayPresentationChanged() {
    if (_overlayEntry == null) return;
    _overlayRefreshTick.value += 1;
  }

  Widget _buildTransformedPresentationChild(Widget? child) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
        ..scaleByDouble(_scale, _scale, 1, 1),
      child: child,
    );
  }

  ({Offset centroid, double span}) _calculatePointerMetrics() {
    var dx = 0.0;
    var dy = 0.0;
    var count = 0;

    for (final point in _activePointers.values) {
      dx += point.dx;
      dy += point.dy;
      count += 1;
    }

    if (count == 0) {
      return (centroid: Offset.zero, span: 0.0);
    }

    final centroid = Offset(dx / count, dy / count);
    if (count < 2) {
      return (centroid: centroid, span: 0.0);
    }

    var totalDistance = 0.0;
    for (final point in _activePointers.values) {
      totalDistance += (point - centroid).distance;
    }

    return (centroid: centroid, span: totalDistance / count);
  }

  Offset _centeredPoint(Offset point) {
    final size = _viewportSize;
    return Offset(point.dx - (size.width / 2), point.dy - (size.height / 2));
  }

  double _applyScaleResistance(double rawScale) {
    if (rawScale < widget.minScale) {
      final overshoot = widget.minScale - rawScale;
      return widget.minScale - (overshoot / (1 + (overshoot * 4)));
    }

    if (rawScale > widget.maxScale) {
      final overshoot = rawScale - widget.maxScale;
      return widget.maxScale + (overshoot / (1 + (overshoot * 4)));
    }

    return rawScale;
  }

  Offset _offsetForFocalLock({
    required double startScale,
    required double nextScale,
    required Offset startOffset,
    required Offset startFocalPoint,
    required Offset currentFocalPoint,
  }) {
    final safeScale = startScale.abs() < 0.0001 ? widget.minScale : startScale;

    // This is equivalent to translate-to-focal -> scale -> translate-back.
    final anchoredContentPoint = Offset(
      (startFocalPoint.dx - startOffset.dx) / safeScale,
      (startFocalPoint.dy - startOffset.dy) / safeScale,
    );

    return Offset(
      currentFocalPoint.dx - (anchoredContentPoint.dx * nextScale),
      currentFocalPoint.dy - (anchoredContentPoint.dy * nextScale),
    );
  }

  Offset _softClampOffset(Offset value, double scale, Size size) {
    final horizontalLimit =
        math.max(0.0, (size.width * (scale - 1)) / 2) *
        _horizontalPanLimitFactor;
    final verticalLimit =
        math.max(0.0, (size.height * (scale - 1)) / 2) *
        _verticalPanLimitFactor;

    return Offset(
      _softClampAxis(
        value.dx,
        horizontalLimit,
        maxOverflow: _maxHorizontalOverflow,
      ),
      _softClampAxis(
        value.dy,
        verticalLimit,
        maxOverflow: _maxVerticalOverflow,
      ),
    );
  }

  double _softClampAxis(
    double value,
    double limit, {
    required double maxOverflow,
  }) {
    if (limit <= 0) {
      return value * _softClampResistance;
    }

    final distance = value.abs();
    if (distance <= limit) return value;

    final overflow = distance - limit;
    final resistedOverflow =
        ((overflow / (1 + (overflow / 24))) * _softClampResistance).clamp(
          0.0,
          maxOverflow,
        );
    return value.sign * (limit + resistedOverflow);
  }

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).scaffoldBackgroundColor;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        child: RepaintBoundary(
          child: _showInlineSource
              ? widget.child
              : SizedBox(
                  width: _cachedViewportSize?.width ?? _viewportSize.width,
                  height: _cachedViewportSize?.height ?? _viewportSize.height,
                  child: ColoredBox(
                    color: placeholderColor,
                    child: const SizedBox.expand(),
                  ),
                ),
        ),
      ),
    );
  }
}
