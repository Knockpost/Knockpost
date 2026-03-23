// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Canvas size — flutter_native_splash scales this to screen
  int canvasSize = 1152;
  
  // How big the icon should appear inside the canvas (smaller = appears smaller on screen)
  int iconSize = 600;

  final files = [
    ('assets/icon(light backgroud).png', 'assets/splash_icon_light.png'),
    ('assets/icon(drak background).png', 'assets/splash_icon_dark.png'),
  ];

  for (final (inputPath, outputPath) in files) {
    final src = img.decodeImage(File(inputPath).readAsBytesSync())!;

    // Resize icon to desired display size
    final resized = img.copyResize(src, width: iconSize, height: iconSize, interpolation: img.Interpolation.cubic);

    // Place on a large transparent canvas
    final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

    int dx = (canvasSize - resized.width) ~/ 2;
    int dy = (canvasSize - resized.height) ~/ 2;
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

    File(outputPath).writeAsBytesSync(img.encodePng(canvas));
    print('Generated $outputPath (icon at ${iconSize}px on $canvasSize x $canvasSize canvas)');
  }
}
