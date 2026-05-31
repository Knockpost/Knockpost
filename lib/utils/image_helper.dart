import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  /// Resolves a path string (assets/, http(s)://, or local file) to an [ImageProvider].
  /// Returns null if [path] is null or empty.
  static ImageProvider? resolveImage(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('assets/')) return AssetImage(path);
    if (path.startsWith('http')) return CachedNetworkImageProvider(path, cacheManager: KnockpostImageCacheManager.instance);
    return FileImage(File(path));
  }

  /// Convenience wrapper for user avatar / cover paths.
  static ImageProvider? resolveAvatar(String? avatarPath) =>
      resolveImage(avatarPath);
}
