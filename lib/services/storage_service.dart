import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a post media file (image/video) to Storage.
  /// Path: posts/{userId}/{postId}/{fileName}
  Future<String?> uploadPostMedia({
    required String userId,
    required String postId,
    required File file,
  }) async {
    try {
      final fileName = p.basename(file.path);
      final ref = _storage.ref().child('posts/$userId/$postId/$fileName');

      // Upload file
      final uploadTask = await ref.putFile(file);
      
      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading post media: $e");
      return null;
    }
  }

  /// Uploads a post cover image to Storage.
  /// Path: posts/{userId}/{postId}/cover_{fileName}
  Future<String?> uploadPostCoverImage({
    required String userId,
    required String postId,
    required File file,
  }) async {
    try {
      final fileName = p.basename(file.path);
      final ref = _storage.ref().child('posts/$userId/$postId/cover_$fileName');

      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading cover image: $e");
      return null;
    }
  }

  /// Uploads a chat image (from memory) to Storage.
  /// Path: chats/{chatId}/{messageId}.jpg
  Future<String?> uploadChatImage({
    required String chatId,
    required String messageId,
    required Uint8List bytes,
  }) async {
    try {
      final ref = _storage.ref().child('chats/$chatId/$messageId.jpg');
      
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putData(bytes, metadata);
      
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading chat image: $e");
      return null;
    }
  }

  /// Uploads a profile picture to Storage.
  /// Path: users/{userId}/avatar_{timestamp}.ext
  Future<String?> uploadProfilePicture({
    required String userId,
    required File file,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(file.path);
      final ref = _storage.ref().child('users/$userId/avatar_$timestamp$ext');

      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading profile picture: $e");
      return null;
    }
  }

  /// Uploads a profile cover image to Storage.
  /// Path: users/{userId}/cover_{timestamp}.ext
  Future<String?> uploadCoverPicture({
    required String userId,
    required File file,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(file.path);
      final ref = _storage.ref().child('users/$userId/cover_$timestamp$ext');

      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading cover picture: $e");
      return null;
    }
  }
}
