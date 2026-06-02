import 'dart:math';
import 'dart:ui';

import '../models/media_transform.dart';

/// Shared math utilities for the unified media transform engine.
///
/// Every screen that displays transformed media (editor, feed, export) must
/// use these functions — never inline its own transform math. This is the
/// single source of truth that guarantees visual consistency.
class MediaTransformUtils {
  MediaTransformUtils._();

  // ─── Core scale calculation ──────────────────────────────────────────────

  /// The minimum scale that fully covers the canvas with no black bars.
  ///
  /// This is `max(canvasW / mediaW, canvasH / mediaH)`, which is the
  /// classic "cover" fit. The media may extend beyond the canvas but
  /// will never leave any edge uncovered.
  static double coverScale(Size mediaSize, Size canvasSize) {
    if (mediaSize.width <= 0 || mediaSize.height <= 0) return 1.0;
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return 1.0;
    return max(
      canvasSize.width / mediaSize.width,
      canvasSize.height / mediaSize.height,
    );
  }

  // ─── Offset clamping ────────────────────────────────────────────────────

  /// Clamps a proposed offset so the media never exposes canvas edges.
  ///
  /// The drawn media size is `mediaSize * coverScale * userScale`. The
  /// maximum allowed panning distance in each axis is
  /// `(drawnDimension - canvasDimension) / 2`.
  static Offset clampOffset({
    required Offset proposed,
    required double scale,
    required Size mediaSize,
    required Size canvasSize,
  }) {
    final double base = coverScale(mediaSize, canvasSize);
    final double drawnWidth = mediaSize.width * base * scale;
    final double drawnHeight = mediaSize.height * base * scale;
    final double maxDx = max(0.0, (drawnWidth - canvasSize.width) / 2.0);
    final double maxDy = max(0.0, (drawnHeight - canvasSize.height) / 2.0);

    return Offset(
      proposed.dx.clamp(-maxDx, maxDx).toDouble(),
      proposed.dy.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  // ─── Rendering helpers ──────────────────────────────────────────────────

  /// Builds the destination rectangle for rendering media onto a canvas.
  ///
  /// The rectangle may extend beyond the canvas bounds (the caller should
  /// clip). This is used identically by the editor preview, the feed
  /// `WaveItem`, and the FFmpeg crop calculator.
  static Rect buildDrawRect({
    required Size canvasSize,
    required Size mediaSize,
    required MediaTransform transform,
  }) {
    // Proportionally rescale translation from the original container to the
    // current canvas size.
    final double scaleRatioX = transform.containerWidth > 0
        ? canvasSize.width / transform.containerWidth
        : 1.0;
    final double scaleRatioY = transform.containerHeight > 0
        ? canvasSize.height / transform.containerHeight
        : 1.0;

    final double dx = transform.translateX * scaleRatioX;
    final double dy = transform.translateY * scaleRatioY;

    final double base = coverScale(mediaSize, canvasSize);
    final double displayScale = base * transform.scale;
    final double drawWidth = mediaSize.width * displayScale;
    final double drawHeight = mediaSize.height * displayScale;

    return Rect.fromLTWH(
      canvasSize.width / 2.0 + dx - drawWidth / 2.0,
      canvasSize.height / 2.0 + dy - drawHeight / 2.0,
      drawWidth,
      drawHeight,
    );
  }

  // ─── FFmpeg export support ──────────────────────────────────────────────

  /// Converts a UI transform into a source-pixel crop rect for FFmpeg.
  ///
  /// The resulting rect is in the coordinate space of the original media
  /// file (pixels), suitable for an FFmpeg `crop=w:h:x:y` filter.
  static Rect buildSourceCropRect({
    required Size canvasSize,
    required Size mediaSize,
    required MediaTransform transform,
  }) {
    final Rect drawRect = buildDrawRect(
      canvasSize: canvasSize,
      mediaSize: mediaSize,
      transform: transform,
    );
    final double scale = drawRect.width / mediaSize.width;

    return Rect.fromLTWH(
      ((0 - drawRect.left) / scale).clamp(0.0, mediaSize.width),
      ((0 - drawRect.top) / scale).clamp(0.0, mediaSize.height),
      (canvasSize.width / scale).clamp(1.0, mediaSize.width),
      (canvasSize.height / scale).clamp(1.0, mediaSize.height),
    );
  }

  // ─── Rescaling ──────────────────────────────────────────────────────────

  /// Rescales a transform from its original container to a new canvas size.
  ///
  /// The user's scale value and proportional translation are preserved, so
  /// the visual result is identical at any display resolution.
  static MediaTransform rescale(MediaTransform source, Size targetCanvas) {
    if (source.containerWidth <= 0 || source.containerHeight <= 0) {
      return source;
    }
    final double rx = targetCanvas.width / source.containerWidth;
    final double ry = targetCanvas.height / source.containerHeight;

    return source.copyWith(
      translateX: source.translateX * rx,
      translateY: source.translateY * ry,
      containerWidth: targetCanvas.width,
      containerHeight: targetCanvas.height,
    );
  }

  // ─── Convenience ────────────────────────────────────────────────────────

  /// Clamps a user scale to `[1.0, maxScale]` (relative to cover scale).
  ///
  /// A value of 1.0 means "exactly covering the canvas". Values above 1.0
  /// are zoomed in further. The minimum is always 1.0 so black bars are
  /// impossible.
  static double clampScale(double proposed, {double maxScale = 5.0}) {
    return proposed.clamp(1.0, maxScale).toDouble();
  }
}
