// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final imageFile = File('assets/reaction_default.png');
  if (!imageFile.existsSync()) {
    print('File not found');
    return;
  }
  
  final image = img.decodeImage(imageFile.readAsBytesSync())!;
  
  img.Image reactionLight = img.Image(width: image.width, height: image.height, numChannels: 4);
  img.Image reactionDark = img.Image(width: image.width, height: image.height, numChannels: 4);
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixelSafe(x, y);
      
      // If it's an outline icon, the color is probably black or white, but we just care about alpha or darkness.
      // Let's assume it has an alpha channel. If not, we use the darkness.
      int alpha = p.a.toInt();
      
      // If the image is fully opaque but has a white background:
      if (alpha == 255 && p.r > 240 && p.g > 240 && p.b > 240) {
        alpha = 0;
      } else if (alpha == 255) {
        // If it's a black pixel on white background, we might need to threshold it.
        // Let's use the darkness as alpha.
        double darkness = 1.0 - (p.r / 255.0);
        alpha = (darkness * 255).clamp(0, 255).toInt();
      }
      
      // Light Mode icon: The background in the UI is `bgColor = isDark ? 0xFF2A2A2A : 0xfff2f2f2`
      // So in light mode, the icon should be BLACK.
      reactionLight.setPixelRgba(x, y, 0, 0, 0, alpha);
      
      // Dark Mode icon: WHITE
      reactionDark.setPixelRgba(x, y, 255, 255, 255, alpha);
    }
  }
  
  File('assets/reaction_default_light.png').writeAsBytesSync(img.encodePng(reactionLight));
  File('assets/reaction_default_dark.png').writeAsBytesSync(img.encodePng(reactionDark));
  print('Done generating reaction icons');
}
