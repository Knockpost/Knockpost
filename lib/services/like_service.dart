import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import 'database_service.dart';
import 'post_service.dart';

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
    required String postAuthorId, // Added for notification
    required bool isLiking,
    String reactionType = '❤',
    String? postThumbnailUrl,     // Added for notification
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    final authorRef = _firestore.collection('users').doc(postAuthorId);

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
            transaction.update(authorRef, {'totalLikes': FieldValue.increment(1)});
          }
          transaction.set(likeRef, {
            'userId': userId,
            'timestamp': FieldValue.serverTimestamp(),
            'reaction': reactionType,
          });
        } else {
          final likeSnapshot = await transaction.get(likeRef);
          if (likeSnapshot.exists) {
            transaction.delete(likeRef);
            transaction.update(postRef, {'likes': (currentLikes - 1).clamp(0, double.infinity).toInt()});
            transaction.update(authorRef, {'totalLikes': FieldValue.increment(-1)});
          }
        }
      });

      // Send notification if liking and not self
      if (isLiking && userId != postAuthorId) {
        NotificationService.instance.sendNotification(
          receiverUid: postAuthorId,
          type: NotificationType.like,
          postId: postId,
          postThumbnailUrl: postThumbnailUrl,
        );
      }
      
      // Ensure reacting explicitly records a view
      if (isLiking) {
        PostService.instance.incrementViewCount(postId, postAuthorId);
      }
      
      // Recalculate rank asynchronously
      DatabaseService.instance.recalculateCreatorRank(postAuthorId);
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
  /// Deduplicates by userId and handles docs with null timestamps
  /// (which occur briefly when FieldValue.serverTimestamp() hasn't resolved).
  Stream<List<Map<String, dynamic>>> getPostReactions(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .snapshots()
        .asyncMap((snapshot) async {
      final seen = <String>{};
      final reactions = <Map<String, dynamic>>[];
      
      // Sort docs: non-null timestamps first (descending), null timestamps last
      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aTs = a.data()['timestamp'] as Timestamp?;
          final bTs = b.data()['timestamp'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;  // null goes to end
          if (bTs == null) return -1; // null goes to end
          return bTs.compareTo(aTs);  // descending
        });
      
      for (final doc in sortedDocs) {
        final data = doc.data();
        final userId = data['userId'] as String? ?? doc.id;
        data['userId'] = userId; // ensure userId is always set
        if (seen.add(userId)) {
          // Verify user exists to exclude deleted accounts from counts
          final userMap = await DatabaseService.instance.getUserProfile(userId, useCache: true);
          if (userMap != null) {
            reactions.add(data);
          }
        }
      }
      return reactions;
    });
  }

  /// Fetches the user's specific reaction emoji as a Future.
  Future<String?> getUserReactionFuture(String postId, String userId) async {
    if (userId.isEmpty || postId.isEmpty) return null;
    try {
      final doc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['reaction'] as String? ?? '❤';
    } catch (e) {
      debugPrint('Error fetching user reaction: $e');
      return null;
    }
  }

  /// Fetches the list of all reactions for a post as a one-time Future.
  Future<List<Map<String, dynamic>>> getPostReactionsFuture(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .get();

      final seen = <String>{};
      final reactions = <Map<String, dynamic>>[];
      
      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aTs = a.data()['timestamp'] as Timestamp?;
          final bTs = b.data()['timestamp'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
      
      for (final doc in sortedDocs) {
        final data = doc.data();
        final userId = data['userId'] as String? ?? doc.id;
        data['userId'] = userId;
        if (seen.add(userId)) {
          final userMap = await DatabaseService.instance.getUserProfile(userId, useCache: true);
          if (userMap != null) {
            reactions.add(data);
          }
        }
      }
      return reactions;
    } catch (e) {
      debugPrint('Error fetching post reactions future: $e');
      return [];
    }
  }
}
