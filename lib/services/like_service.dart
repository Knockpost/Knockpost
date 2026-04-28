import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LikeService {
  LikeService._internal();
  static final LikeService instance = LikeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Toggles a like on a post.
  /// Uses a transaction to safely increment/decrement the post's like count
  /// and add/remove the user's ID from the post's `likes` subcollection.
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool isLiking,
    String reactionType = '❤',
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);

        if (!postSnapshot.exists) {
          throw Exception("Post does not exist!");
        }

        final currentLikes = postSnapshot.data()?['likes'] as int? ?? 0;

        if (isLiking) {
          final likeSnapshot = await transaction.get(likeRef);
          if (!likeSnapshot.exists) {
            transaction.update(postRef, {'likes': currentLikes + 1});
          }
          transaction.set(likeRef, {
            'timestamp': FieldValue.serverTimestamp(),
            'reaction': reactionType,
          });
        } else {
          final likeSnapshot = await transaction.get(likeRef);
          if (likeSnapshot.exists) {
            transaction.delete(likeRef);
            transaction.update(postRef, {'likes': (currentLikes - 1).clamp(0, double.infinity).toInt()});
          }
        }
      });
    } catch (e) {
      debugPrint("Error toggling like: $e");
      rethrow;
    }
  }

  /// Streams the user's specific reaction emoji (e.g., '❤' or '😂').
  /// Returns null if the user hasn't reacted.
  Stream<String?> userReaction(String postId, String userId) {
    if (userId.isEmpty || postId.isEmpty) return Stream.value(null);
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data()?['reaction'] as String? ?? '❤';
    });
  }

  /// Streams the list of all reactions for a post.
  Stream<List<Map<String, dynamic>>> getPostReactions(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['userId'] = doc.id;
        return data;
      }).toList();
    });
  }
}
