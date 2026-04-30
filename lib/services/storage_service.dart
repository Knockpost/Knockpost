import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Compresses an image file before uploading.
  /// Returns the original file if compression fails.
  Future<File> _compressImage(File file, {int quality = 75, int maxSize = 1280}) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      // Skip non-image files (videos, etc.)
      if (ext == '.mp4' || ext == '.mov' || ext == '.mkv') return file;

      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxSize,
        minHeight: maxSize,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressed = File(result.path);
        debugPrint(
          'StorageService: image compressed '
          '${(file.lengthSync() / 1024).toStringAsFixed(0)}KB → '
          '${(compressed.lengthSync() / 1024).toStringAsFixed(0)}KB',
        );
        return compressed;
      }
    } catch (e) {
      debugPrint('StorageService: image compression failed, using original: $e');
    }
    return file;
  }

  /// Compresses a video file before uploading.
  /// Returns the original file if compression fails.
  Future<File> _compressVideo(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (info != null && info.file != null) {
        debugPrint(
          'StorageService: video compressed '
          '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)}MB → '
          '${((info.file!.lengthSync()) / 1024 / 1024).toStringAsFixed(1)}MB',
        );
        return info.file!;
      }
    } catch (e) {
      debugPrint('StorageService: video compression failed, using original: $e');
    }
    return file;
  }

  /// Returns true if the given file path looks like a video.
  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.mp4' || ext == '.mov' || ext == '.mkv' || ext == '.webm';
  }

  // ── Public upload methods ──────────────────────────────────────────────────

  /// Uploads a post media file (image/video) to Storage.
  /// Automatically compresses before uploading.
  /// Path: posts/{userId}/{postId}/{fileName}
  Future<String?> uploadPostMedia({
    required String userId,
    required String postId,
    required File file,
  }) async {
    try {
      // Compress before uploading
      final toUpload = _isVideo(file.path)
          ? await _compressVideo(file)
          : await _compressImage(file);

      final fileName = p.basename(toUpload.path);
      final ref = _storage.ref().child('posts/$userId/$postId/$fileName');
      final uploadTask = await ref.putFile(toUpload);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading post media: $e");
      return null;
    }
  }

  /// Uploads a post cover image to Storage.
  /// Automatically compresses before uploading.
  /// Path: posts/{userId}/{postId}/cover_{fileName}
  Future<String?> uploadPostCoverImage({
    required String userId,
    required String postId,
    required File file,
  }) async {
    try {
      final compressed = await _compressImage(file, quality: 70, maxSize: 720);
      final fileName = 'cover_${p.basename(file.path)}';
      final ref = _storage.ref().child('posts/$userId/$postId/$fileName');
      final uploadTask = await ref.putFile(compressed);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading cover image: $e");
      return null;
    }
  }

  /// Uploads a chat image (from memory bytes) to Storage.
  /// Path: chats/{chatId}/{messageId}.jpg
  Future<String?> uploadChatImage({
    required String chatId,
    required String messageId,
    required Uint8List bytes,
  }) async {
    try {
      // Compress in-memory bytes
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );

      final ref = _storage.ref().child('chats/$chatId/$messageId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putData(compressed, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading chat image: $e");
      return null;
    }
  }

  /// Uploads a profile picture to Storage.
  /// Automatically compresses before uploading.
  /// Path: users/{userId}/avatar_{timestamp}.jpg
  Future<String?> uploadProfilePicture({
    required String userId,
    required File file,
  }) async {
    try {
      final compressed = await _compressImage(file, quality: 80, maxSize: 512);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('users/$userId/avatar_$timestamp.jpg');
      final uploadTask = await ref.putFile(compressed);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading profile picture: $e");
      return null;
    }
  }

  /// Uploads a profile cover image to Storage.
  /// Automatically compresses before uploading.
  /// Path: users/{userId}/cover_{timestamp}.jpg
  Future<String?> uploadCoverPicture({
    required String userId,
    required File file,
  }) async {
    try {
      final compressed = await _compressImage(file, quality: 75, maxSize: 1080);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('users/$userId/cover_$timestamp.jpg');
      final uploadTask = await ref.putFile(compressed);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading cover picture: $e");
      return null;
    }
  }
}
