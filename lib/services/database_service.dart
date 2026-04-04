import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get usersCollection => _firestore.collection('users');

  /// Check if a username is already taken.
  Future<bool> checkUsernameTaken(String username) async {
    try {
      final result = await usersCollection
          .where('username', isEqualTo: username.toLowerCase().trim())
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking username: $e");
      return true; // fail-safe, assume taken if error
    }
  }

  /// Create a user profile in Firestore
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String username,
    required String fullName,
    String profileImageUrl = "",
    List<String> interests = const [],
  }) async {
    try {
      // Ensure username is properly case-insensitive for unique searches if needed
      await usersCollection.doc(uid).set({
        'uid': uid,
        'email': email,
        'username': username.toLowerCase().trim(),
        'displayName': fullName,
        'profileImageUrl': profileImageUrl,
        'interests': interests,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error creating user profile: $e");
      rethrow;
    }
  }

  /// Fetch a user profile by UID
  Future<Map<String, dynamic>?> getUserProfile(String uid, {bool useCache = false}) async {
    try {
      final options = useCache ? const GetOptions(source: Source.cache) : const GetOptions();
      DocumentSnapshot doc = await usersCollection.doc(uid).get(options);
      
      if (!doc.exists && useCache) {
        // Fallback to server if cache doesn't have it
        doc = await usersCollection.doc(uid).get();
      }

      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null;
    }
  }
}
