/// Unified media transform data model.
///
/// Stores the exact transform applied to media in the editor, and is
/// reused identically in the feed renderer and the FFmpeg export pipeline.
/// This ensures pixel-identical output across all three surfaces.
///
/// The transform is always relative to a specific container (canvas) size.
/// When rendering at a different canvas size, use [rescale] to proportionally
/// adjust translations.
class MediaTransform {
  /// Zoom level. 1.0 = cover scale (no black bars).
  /// Must always be >= the cover scale for the given media/canvas pair.
  final double scale;

  /// Horizontal translation in logical pixels (relative to [containerWidth]).
  final double translateX;

  /// Vertical translation in logical pixels (relative to [containerHeight]).
  final double translateY;

  /// The width of the editor canvas when this transform was created.
  final double containerWidth;

  /// The height of the editor canvas when this transform was created.
  final double containerHeight;

  const MediaTransform({
    this.scale = 1.0,
    this.translateX = 0.0,
    this.translateY = 0.0,
    this.containerWidth = 1080.0,
    this.containerHeight = 1920.0,
  });

  /// Identity transform — no zoom, no pan.
  const MediaTransform.identity()
      : scale = 1.0,
        translateX = 0.0,
        translateY = 0.0,
        containerWidth = 1080.0,
        containerHeight = 1920.0;

  /// Create a copy with some fields overridden.
  MediaTransform copyWith({
    double? scale,
    double? translateX,
    double? translateY,
    double? containerWidth,
    double? containerHeight,
  }) {
    return MediaTransform(
      scale: scale ?? this.scale,
      translateX: translateX ?? this.translateX,
      translateY: translateY ?? this.translateY,
      containerWidth: containerWidth ?? this.containerWidth,
      containerHeight: containerHeight ?? this.containerHeight,
    );
  }

  /// Serialize to a map for Firestore storage via [PostModel.mediaTransform].
  Map<String, dynamic> toMap() {
    return {
      'scale': scale,
      'translateX': translateX,
      'translateY': translateY,
      'containerWidth': containerWidth,
      'containerHeight': containerHeight,
    };
  }

  /// Deserialize from a Firestore map.
  ///
  /// Gracefully handles legacy fields (e.g. `rotation`) by ignoring them.
  factory MediaTransform.fromMap(Map<String, dynamic> map) {
    return MediaTransform(
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      translateX: (map['translateX'] as num?)?.toDouble() ?? 0.0,
      translateY: (map['translateY'] as num?)?.toDouble() ?? 0.0,
      containerWidth: (map['containerWidth'] as num?)?.toDouble() ?? 1080.0,
      containerHeight: (map['containerHeight'] as num?)?.toDouble() ?? 1920.0,
    );
  }

  /// Whether this transform is effectively a no-op (identity).
  bool get isIdentity =>
      (scale - 1.0).abs() < 0.001 &&
      translateX.abs() < 0.5 &&
      translateY.abs() < 0.5;

  @override
  String toString() =>
      'MediaTransform(scale: ${scale.toStringAsFixed(3)}, '
      'tx: ${translateX.toStringAsFixed(1)}, '
      'ty: ${translateY.toStringAsFixed(1)}, '
      'cw: ${containerWidth.toStringAsFixed(0)}, '
      'ch: ${containerHeight.toStringAsFixed(0)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaTransform &&
          runtimeType == other.runtimeType &&
          scale == other.scale &&
          translateX == other.translateX &&
          translateY == other.translateY &&
          containerWidth == other.containerWidth &&
          containerHeight == other.containerHeight;

  @override
  int get hashCode => Object.hash(
        scale,
        translateX,
        translateY,
        containerWidth,
        containerHeight,
      );
}
