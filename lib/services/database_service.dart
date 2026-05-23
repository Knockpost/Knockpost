import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get usersCollection => _firestore.collection('users');

  /// Recalculate and update the creator rank for a user based on their stats.
  Future<void> recalculateCreatorRank(String uid) async {
    try {
      final doc = await usersCollection.doc(uid).get();
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      final accountType = data['accountType'] as String?;
      if (accountType != 'creator') return;

      final totalViews = data['totalViews'] as int? ?? 0;
      final totalLikes = data['totalLikes'] as int? ?? 0;
      final totalKnocks = data['totalKnocksReceived'] as int? ?? 0;
      
      // Calculate new rank
      // IMPACT: views >= 10k, likes >= 5k, knocks >= 500
      // PRO: views >= 5k, likes >= 2k, knocks >= 100
      // PLUS: views >= 1k, likes >= 500, knocks >= 50
      // ECHO: default
      CreatorRank newRank = CreatorRank.echo;
      if (totalViews >= 10000 && totalLikes >= 5000 && totalKnocks >= 500) {
        newRank = CreatorRank.impact;
      } else if (totalViews >= 5000 && totalLikes >= 2000 && totalKnocks >= 100) {
        newRank = CreatorRank.pro;
      } else if (totalViews >= 1000 && totalLikes >= 500 && totalKnocks >= 50) {
        newRank = CreatorRank.plus;
      }
      
      final currentRankStr = data['rank'] as String?;
      if (currentRankStr != newRank.name) {
        await usersCollection.doc(uid).update({
          'rank': newRank.name,
        });
      }
    } catch (e) {
      debugPrint('Error recalculating rank: $e');
    }
  }

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
    String? accountType,
    String? privacyType,
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
      if (accountType != null) {
        data['accountType'] = accountType;
      }
      if (privacyType != null) {
        data['privacyType'] = privacyType;
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

      // Fetch current user's blocked list
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      List<String> myBlockedUsers = [];
      if (myUid != null) {
        final myDoc = await usersCollection.doc(myUid).get();
        if (myDoc.exists) {
          final data = myDoc.data() as Map<String, dynamic>;
          myBlockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        }
      }

      // Merge & deduplicate
      final Map<String, UserModel> combined = {};
      for (final doc in [...usernameSnap.docs, ...nameSnap.docs]) {
        if (excludeUid != null && doc.id == excludeUid) continue;
        if (myUid != null && doc.id == myUid) continue;

        final docData = doc.data() as Map<String, dynamic>;
        final theirBlockedUsers = List<String>.from(docData['blockedUsers'] ?? []);
        
        // Exclude if I blocked them or they blocked me
        if (myBlockedUsers.contains(doc.id) || theirBlockedUsers.contains(myUid)) continue;

        if (!combined.containsKey(doc.id)) {
          combined[doc.id] = UserModel.fromMap(
            docData,
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
      final snap = await usersCollection.limit(limitCount * 2).get(); // fetch more to account for filtered out users
      final List<UserModel> users = [];

      final myUid = FirebaseAuth.instance.currentUser?.uid;
      List<String> myBlockedUsers = [];
      if (myUid != null) {
        final myDoc = await usersCollection.doc(myUid).get();
        if (myDoc.exists) {
          final data = myDoc.data() as Map<String, dynamic>;
          myBlockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        }
      }

      for (final doc in snap.docs) {
        if (users.length >= limitCount) break;
        if (excludeUid != null && doc.id == excludeUid) continue;
        if (myUid != null && doc.id == myUid) continue;

        final docData = doc.data() as Map<String, dynamic>;
        final theirBlockedUsers = List<String>.from(docData['blockedUsers'] ?? []);
        
        // Exclude if I blocked them or they blocked me
        if (myBlockedUsers.contains(doc.id) || theirBlockedUsers.contains(myUid)) continue;

        users.add(UserModel.fromMap(docData, doc.id));
      }
      return users;
    } catch (e) {
      debugPrint("Error fetching suggested users: $e");
      return [];
    }
  }

  /// Block a user
  Future<void> blockUser({required String myUid, required String targetUid}) async {
    try {
      await usersCollection.doc(myUid).update({
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
      });
      
      // Remove any connection documents between these two users
      await _firestore.collection('connections').doc('${myUid}_$targetUid').delete();
      await _firestore.collection('connections').doc('${targetUid}_$myUid').delete();
    } catch (e) {
      debugPrint("Error blocking user: $e");
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser({required String myUid, required String targetUid}) async {
    try {
      await usersCollection.doc(myUid).update({
        'blockedUsers': FieldValue.arrayRemove([targetUid]),
      });
    } catch (e) {
      debugPrint("Error unblocking user: $e");
      rethrow;
    }
  }
}
