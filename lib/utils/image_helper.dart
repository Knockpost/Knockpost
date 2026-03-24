import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from the selected source and immediately launches cropper.
  /// The [cropRatioX] and [cropRatioY] define the aspect ratio lock.
  /// Set [isCircle] to true if you want a circular cropping UI (good for avatars).
  static Future<File?> pickAndCropImage(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
    required double cropRatioX,
    required double cropRatioY,
    bool isCircle = false,
    String title = 'Crop Image',
  }) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (pickedFile == null) return null;

      if (!context.mounted) return null;

      final isDark = Theme.of(context).brightness == Brightness.dark;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: CropAspectRatio(ratioX: cropRatioX, ratioY: cropRatioY),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: isDark ? Colors.black : Colors.white,
            toolbarWidgetColor: isDark ? Colors.white : Colors.black,
            activeControlsWidgetColor: isDark ? Colors.white : Colors.black,
            cropFrameColor: isDark ? Colors.white : Colors.black,
            cropGridColor: isDark ? Colors.white38 : Colors.black38,
            backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
            cropStyle: isCircle ? CropStyle.circle : CropStyle.rectangle,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: isCircle ? CropStyle.circle : CropStyle.rectangle,
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
    } catch (e) {
      debugPrint('Error picking or cropping image: $e');
    }
    return null;
  }
}
