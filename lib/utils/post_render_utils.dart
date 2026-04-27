import 'package:flutter/material.dart';
import 'package:colorfilter_generator/presets.dart';
import 'dart:ui';

class PostRenderUtils {
  static const List<Map<String, dynamic>> carouselEffects = [
    {'id': 'original', 'label': 'Normal'},
    {'id': 'aesthetic', 'label': 'Aesthetic'},
    {'id': 'suave', 'label': 'Suave'},
    {'id': 'losangeles', 'label': 'L.A.'},
    {'id': 'bw', 'label': 'B&W'},
    {'id': 'zohan', 'label': 'Zohan'},
    {'id': 'lowlight', 'label': 'Lowlight'},
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

  static const List<List<double>> photoFilterMatrices = [
    [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0], // 0: Original
    [1.3,0,0,0,0, 0,1.3,0,0,0, 0,0,1.2,0,0, 0,0,0,1,0], // 1: Vivid
    [1.2,0,0,0,10, 0,1.1,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0], // 2: Warm
    [0.9,0,0.1,0,0, 0,1.0,0.1,0,0, 0.1,0,1.2,0,10, 0,0,0,1,0], // 3: Cool
    [0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0,0,0,1,0], // 4: Noir
    [1,0,0,0,20, 0,1,0,0,20, 0,0,1,0,20, 0,0,0,0.85,0], // 5: Fade
    [1.3,0.1,0,0,0, 0,1.1,0.1,0,0, 0,0,1.2,0,0, 0,0,0,1,0], // 6: Chrome
    [0.39,0.77,0.19,0,0, 0.35,0.69,0.17,0,0, 0.27,0.53,0.13,0,0, 0,0,0,1,0], // 7: Sepia
    [1.3,0.1,0,0,10, 0,1.1,0.1,0,5, 0,0.2,1.3,0,20, 0,0,0,1,0], // 8: Cinematic
    [1.2,0,0.5,0,10, 0,0.8,0.5,0,0, 0.5,0,1.2,0,20, 0,0,0,1,0], // 9: Cyber
  ];

  static List<double> _buildAdjustMatrix(double b, double c, double s) {
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

  static List<double> _combineMatrices(List<double> a, List<double> b) {
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

  static ColorFilter getActiveColorFilter(int index, bool isVideoPost) {
    if (!isVideoPost) {
      if (index <= 0 || index >= photoFilterMatrices.length) {
        return const ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      }
      final filter = photoFilterMatrices[index];
      // Since PostModel drops manual adjustments, we rebuild using default sliders (B=0, C=1, S=1)
      final base = _buildAdjustMatrix(0.0, 1.0, 1.0);
      // Multiply matrices accurately to support proper color saturation!
      final combined = _combineMatrices(filter, base);
      return ColorFilter.matrix(combined);
    }

    if (index == 0) {
      return const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    if (index >= carouselEffects.length) index = 0;
    final effectId = carouselEffects[index]['id'];
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

  static Widget applyMediaFilters(Widget child, int filterIndex, bool isVideoPost) {
    if (filterIndex <= 0) return child;

    Widget modified = ColorFiltered(
      colorFilter: getActiveColorFilter(filterIndex, isVideoPost),
      child: child,
    );

    if (!isVideoPost) return modified; // Photo editor doesn't use blend modes/blur!

    final layers = getEffectLayers(filterIndex);
    final blendColor = layers['blendColor'] as Color?;
    final blendMode = layers['blendMode'] as BlendMode?;
    final blurSigma = layers['blur'] as double? ?? 0.0;

    if (blendColor != null && blendMode != null) {
      modified = ColorFiltered(
        colorFilter: ColorFilter.mode(blendColor, blendMode),
        child: modified,
      );
    }

    if (blurSigma > 0) {
      modified = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        ),
        child: modified,
      );
    }

    return modified;
  }

  static Map<String, dynamic> getEffectLayers(int index) {
    if (index == 0 || index >= carouselEffects.length) {
      return {'blur': 0.0, 'vignette': 0.0, 'blendColor': null, 'blendMode': null, 'tint': null, 'lightLeak': null, 'vhsUI': false};
    }
    final effectId = carouselEffects[index]['id'];
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

  static List<Widget> buildEffectOverlayLayers(int filterIndex, bool isVideoPost) {
    if (filterIndex == 0 || !isVideoPost) return [];
    
    final layers = getEffectLayers(filterIndex);
    final vignette = layers['vignette'] as double?;
    final tint = layers['tint'] as Color?;
    final lightLeak = layers['lightLeak'] as List<Color>?;
    final vhsUI = layers['vhsUI'] as bool? ?? false;

    List<Widget> widgets = [];

    if (tint != null) {
      widgets.add(Container(color: tint));
    }
    if (vignette != null && vignette > 0) {
      widgets.add(
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Colors.transparent, Colors.black.withValues(alpha: vignette)],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
      );
    }
    if (lightLeak != null) {
      widgets.add(
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: lightLeak,
            ),
          ),
        ),
      );
    }
    if (vhsUI) {
      widgets.add(
        Positioned(
          left: 30, bottom: 40,
          child: Text('▶ PLAY', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
        )
      );
      widgets.add(
        const Positioned(
          right: 30, bottom: 40,
          child: Text('CH 03', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        )
      );
      widgets.add(
        const Positioned(
          left: 30, top: 40,
          child: Text('REC 🔴', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        )
      );
    }

    return widgets;
  }

  static List<Widget> buildTextOverlays(List<Map<String, dynamic>>? overlays, double containerWidth, double containerHeight, bool isVideoPost) {
    if (overlays == null || overlays.isEmpty) return [];

    return overlays.map((overlay) {
      final text = overlay['text'] as String;
      final xProp = (overlay['x'] as num).toDouble();
      final yProp = (overlay['y'] as num).toDouble();
      final scale = (overlay['scale'] as num?)?.toDouble() ?? 1.0;
      final colorVal = overlay['color'] as int?;
      final color = colorVal != null ? Color(colorVal) : Colors.white;

      final childText = Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: (isVideoPost ? 32 : 28) * scale, // Exact matches for each editor natively
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: isVideoPost ? 3 : 10,
              color: isVideoPost ? Colors.black.withValues(alpha: 0.8) : Colors.black54,
            ),
          ],
        ),
      );

      return Positioned(
        left: xProp * containerWidth,
        top: yProp * containerHeight,
        child: IgnorePointer(
          child: isVideoPost 
            ? childText
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: childText,
              ),
        ),
      );
    }).toList();
  }

  static Widget buildDrawPaths(List<Map<String, dynamic>>? pathsList, double containerWidth, double containerHeight) {
    if (pathsList == null || pathsList.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size(containerWidth, containerHeight),
        painter: _RecreateDrawPainter(pathsList, containerWidth, containerHeight),
      ),
    );
  }
}

class _RecreateDrawPainter extends CustomPainter {
  final List<Map<String, dynamic>> pathsList;
  final double width;
  final double height;

  _RecreateDrawPainter(this.pathsList, this.width, this.height);

  @override
  void paint(Canvas canvas, Size size) {
    for (final pathData in pathsList) {
      final colorVal = pathData['color'] as int?;
      final strokeWidth = (pathData['strokeWidth'] as num?)?.toDouble() ?? 4.0;
      final pointsData = pathData['points'] as List<dynamic>?;
      
      if (pointsData == null || pointsData.isEmpty) continue;

      final paint = Paint()
        ..color = colorVal != null ? Color(colorVal) : Colors.white
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < pointsData.length; i++) {
        final pt = pointsData[i] as Map<String, dynamic>;
        final dx = (pt['x'] as num).toDouble() * width;
        final dy = (pt['y'] as num).toDouble() * height;
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
