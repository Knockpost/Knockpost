// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const canvasSize = 1152;
  const iconSize = 600;
  const upscaleSize = 1800;

  final outputs = [
    ('assets/icon(light backgroud).png', 'assets/splash_icon_light.png'),
    ('assets/icon(drak background).png', 'assets/splash_icon_dark.png'),
  ];

  for (final (inputPath, outputPath) in outputs) {
    final source = img.decodeImage(File(inputPath).readAsBytesSync())!;
    final upscaled = img.copyResize(
      source,
      width: upscaleSize,
      height: upscaleSize,
      interpolation: img.Interpolation.cubic,
    );
    final sharpened = img.convolution(
      upscaled,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
    );
    final resized = img.copyResize(
      sharpened,
      width: iconSize,
      height: iconSize,
      interpolation: img.Interpolation.cubic,
    );

    final canvas = img.Image(
      width: canvasSize,
      height: canvasSize,
      numChannels: 4,
    );
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

    // ignore: prefer_const_declarations
    final offset = (canvasSize - iconSize) ~/ 2;
    img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

    File(outputPath).writeAsBytesSync(img.encodePng(canvas));
    print('Generated $outputPath');
  }
}
