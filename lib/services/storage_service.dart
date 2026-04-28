import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();

  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a profile image to Firebase Storage and returns the download URL.
  Future<String?> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading profile image: $e");
      return null;
    }
  }

  /// Uploads multiple media files for a post and returns their download URLs.
  Future<List<String>> uploadPostMedia(String postId, List<File> files) async {
    List<String> downloadUrls = [];
    try {
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final extension = file.path.split('.').last.toLowerCase();
        final fileName = '${postId}_$i.$extension';
        final ref = _storage.ref().child('posts').child(postId).child(fileName);
        
        final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
        final contentType = isVideo ? 'video/mp4' : 'image/$extension';
        
        await ref.putFile(file, SettableMetadata(contentType: contentType));
        final url = await ref.getDownloadURL();
        downloadUrls.add(url);
      }
      return downloadUrls;
    } catch (e) {
      debugPrint("Error uploading post media: $e");
      return downloadUrls;
    }
  }

  /// Uploads a cover image for a video post.
  Future<String?> uploadPostCoverImage(String postId, File coverFile) async {
    try {
      final ref = _storage.ref().child('posts').child(postId).child('cover.jpg');
      await ref.putFile(coverFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading post cover image: $e");
      return null;
    }
  }
}
