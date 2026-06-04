import 'package:flutter/material.dart';

import '../models/media_transform.dart';
import '../utils/media_transform_utils.dart';

/// Interactive media viewer with pinch-to-zoom and pan gestures.
///
/// This widget is the single interactive transform surface used by all editor
/// screens. It enforces the no-black-bar constraint by clamping scale to
/// the cover minimum and clamping offset so media edges never pull away
/// from the canvas.
///
/// When [interactive] is false, it simply renders the child at the given
/// transform (used in the feed).
class MediaTransformViewer extends StatefulWidget {
  /// The media content widget (video player, image, etc.).
  final Widget child;

  /// Optional blurred background layer (used for Glimpse mode).
  final Widget? background;

  /// The native pixel dimensions of the source media.
  final Size mediaSize;

  /// Initial transform state.
  final MediaTransform initialTransform;

  /// Whether pinch/pan gestures are enabled.
  final bool interactive;

  /// If true, the child is rendered with BoxFit.contain over the background
  /// (Glimpse mode). If false, child fills the canvas (Waves mode).
  final bool isGlimpse;

  /// Called on every gesture update with the new transform.
  final ValueChanged<MediaTransform>? onTransformChanged;

  const MediaTransformViewer({
    super.key,
    required this.child,
    this.background,
    required this.mediaSize,
    this.initialTransform = const MediaTransform.identity(),
    this.interactive = true,
    this.isGlimpse = false,
    this.onTransformChanged,
  });

  @override
  State<MediaTransformViewer> createState() => MediaTransformViewerState();
}

class MediaTransformViewerState extends State<MediaTransformViewer> {
  late double _scale;
  late Offset _offset;

  // Gesture baseline values
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _focalPoint = Offset.zero;

  /// Expose current transform for external reads (e.g. when publishing).
  MediaTransform get currentTransform => MediaTransform(
        scale: _scale,
        translateX: _offset.dx,
        translateY: _offset.dy,
        containerWidth: _lastCanvasSize.width,
        containerHeight: _lastCanvasSize.height,
      );

  Size _lastCanvasSize = const Size(1080, 1920);

  @override
  void initState() {
    super.initState();
    _scale = widget.initialTransform.scale;
    _offset = Offset(
      widget.initialTransform.translateX,
      widget.initialTransform.translateY,
    );
  }

  @override
  void didUpdateWidget(covariant MediaTransformViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initial transform changes externally (e.g. reset), sync state.
    if (widget.initialTransform != oldWidget.initialTransform &&
        !widget.interactive) {
      _scale = widget.initialTransform.scale;
      _offset = Offset(
        widget.initialTransform.translateX,
        widget.initialTransform.translateY,
      );
    }
  }

  void _notifyChanged() {
    widget.onTransformChanged?.call(currentTransform);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        _lastCanvasSize = canvasSize;

        // Build the draw rect using shared math
        final transform = currentTransform.copyWith(
          containerWidth: canvasSize.width,
          containerHeight: canvasSize.height,
        );
        final drawRect = MediaTransformUtils.buildDrawRect(
          canvasSize: canvasSize,
          mediaSize: widget.mediaSize,
          transform: transform,
        );

        Widget content = ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background layer (black for Waves, blurred for Glimpse)
              if (widget.isGlimpse && widget.background != null)
                widget.background!
              else
                Container(color: Colors.black),

              // Transformed foreground media
              Positioned.fromRect(
                rect: drawRect,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: widget.mediaSize.width,
                    height: widget.mediaSize.height,
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        );

        if (!widget.interactive) return content;

        // Wrap in gesture detector for pinch/pan
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: (details) => _onScaleUpdate(details, canvasSize),
          onScaleEnd: (details) => _onScaleEnd(canvasSize),
          child: content,
        );
      },
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _focalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size canvasSize) {
    setState(() {
      // Clamp scale: minimum 1.0 (= cover scale), maximum 5.0
      _scale = MediaTransformUtils.clampScale(
        _baseScale * details.scale,
      );

      // Apply pan delta
      final proposedOffset = _baseOffset + (details.focalPoint - _focalPoint);

      // Clamp offset so media never pulls away from canvas edges
      _offset = MediaTransformUtils.clampOffset(
        proposed: proposedOffset,
        scale: _scale,
        mediaSize: widget.mediaSize,
        canvasSize: canvasSize,
      );
    });
    _notifyChanged();
  }

  void _onScaleEnd(Size canvasSize) {
    // Final clamp on release
    setState(() {
      _offset = MediaTransformUtils.clampOffset(
        proposed: _offset,
        scale: _scale,
        mediaSize: widget.mediaSize,
        canvasSize: canvasSize,
      );
    });
    _notifyChanged();
  }

  /// Programmatically reset to identity.
  void reset() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
    _notifyChanged();
  }
}
