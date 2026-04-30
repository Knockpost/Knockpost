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
        'displayNameLower': fullName.toLowerCase().trim(),
        'profileImageUrl': profileImageUrl,
        'interests': interests,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error creating user profile: $e");
      rethrow;
    }
  }

  /// Update an existing user profile in Firestore
  Future<void> updateUserProfile({
    required String uid,
    required String displayName,
    required String username,
    String? bio,
    String? profileImageUrl,
    String? coverImageUrl,
    Map<String, String>? socialLinks,
  }) async {
    try {
      final data = <String, dynamic>{
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase().trim(),
        'username': username.toLowerCase().trim(),
        'bio': bio ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (profileImageUrl != null) {
        data['profileImageUrl'] = profileImageUrl;
      }
      if (coverImageUrl != null) {
        data['coverImageUrl'] = coverImageUrl;
      }
      if (socialLinks != null) {
        data['socialLinks'] = socialLinks;
      }

      await usersCollection.doc(uid).update(data);
    } catch (e) {
      debugPrint("Error updating user profile: $e");
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

  /// Fetch a UserModel by UID. Returns null if not found.
  Future<UserModel?> getUserById(String uid) async {
    try {
      final data = await getUserProfile(uid, useCache: true);
      if (data != null) {
        return UserModel.fromMap(data, uid);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user by id: $e");
      return null;
    }
  }

  /// Search users by username prefix (case-insensitive via lowercase storage).
  /// Also fetches by displayName prefix as a second query.
  Future<List<UserModel>> searchUsers(String query, {String? excludeUid}) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final end = q.substring(0, q.length - 1) + String.fromCharCode(q.codeUnitAt(q.length - 1) + 1);

    try {
      // Query 1: by username prefix
      final usernameSnap = await usersCollection
          .where('username', isGreaterThanOrEqualTo: q)
          .where('username', isLessThan: end)
          .limit(20)
          .get();

      // Query 2: by displayName prefix (stored as-is, so lowercase the field too)
      final nameSnap = await usersCollection
          .where('displayNameLower', isGreaterThanOrEqualTo: q)
          .where('displayNameLower', isLessThan: end)
          .limit(20)
          .get();

      // Merge & deduplicate
      final Map<String, UserModel> combined = {};
      for (final doc in [...usernameSnap.docs, ...nameSnap.docs]) {
        if (excludeUid != null && doc.id == excludeUid) continue;
        if (!combined.containsKey(doc.id)) {
          combined[doc.id] = UserModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }
      }
      return combined.values.toList();
    } catch (e) {
      debugPrint("Error searching users: $e");
      return [];
    }
  }

  /// Get a list of suggested users
  Future<List<UserModel>> getSuggestedUsers({String? excludeUid, int limitCount = 10}) async {
    try {
      final snap = await usersCollection.limit(limitCount).get();
      final List<UserModel> users = [];
      for (final doc in snap.docs) {
        if (excludeUid != null && doc.id == excludeUid) continue;
        users.add(UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id));
      }
      return users;
    } catch (e) {
      debugPrint("Error fetching suggested users: $e");
      return [];
    }
  }
}
