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
}
