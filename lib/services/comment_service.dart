import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/reply_thread.dart';

class CommentService {
  CommentService._internal();
  static final CommentService instance = CommentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _threadsRef(String postId) =>
      _firestore.collection('posts').doc(postId).collection('threads');

  CollectionReference _messagesRef(String postId, String threadUserId) =>
      _threadsRef(postId).doc(threadUserId).collection('messages');

  /// Streams the list of reply threads for a post.
  /// If [isPostOwner] is true, it returns all threads for this post.
  /// If false, it returns only the thread belonging to the current user.
  Stream<List<ReplyThread>> getThreadsForPost({
    required String postId,
    required String currentUserId,
    required bool isPostOwner,
  }) {
    Query query = _threadsRef(postId);

    if (!isPostOwner) {
      query = query.where('userId', isEqualTo: currentUserId);
    }

    return query
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReplyThread.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// Streams the messages within a specific thread.
  Stream<List<ReplyMessage>> getMessagesForThread({
    required String postId,
    required String threadUserId,
  }) {
    return _messagesRef(postId, threadUserId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReplyMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Sends a message and updates the thread's last message and unread count.
  Future<void> sendMessage({
    required String postId,
    required String postAuthorId,
    required String senderId,
    required String threadUserId,
    required String text,
  }) async {
    try {
      final now = FieldValue.serverTimestamp();
      final receiverId = senderId == postAuthorId ? threadUserId : postAuthorId;
      
      final messageRef = _messagesRef(postId, threadUserId).doc();
      final threadRef = _threadsRef(postId).doc(threadUserId);

      await _firestore.runTransaction((transaction) async {
        final threadSnapshot = await transaction.get(threadRef);
        int unreadCount = 0;

        if (threadSnapshot.exists) {
          final data = threadSnapshot.data() as Map<String, dynamic>;
          unreadCount = data['unreadCount'] ?? 0;
        }

        // If the sender is not the post author, we increment the unread count (for the author to see).
        // If the sender IS the author, we reset the unread count (for the viewer to see? Or just 0?).
        // For simplicity, any new message increments unread count if the receiver is not looking.
        // Based on the demo store logic:
        final newUnreadCount = senderId == postAuthorId ? 0 : unreadCount + 1;

        // Set message
        transaction.set(messageRef, {
          'senderId': senderId,
          'receiverId': receiverId,
          'postId': postId,
          'text': text,
          'timestamp': now,
        });

        // Upsert thread
        transaction.set(threadRef, {
          'postId': postId,
          'authorId': postAuthorId,
          'userId': threadUserId,
          'lastMessage': text,
          'lastTimestamp': now,
          'unreadCount': newUnreadCount,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
      rethrow;
    }
  }

  /// Marks a thread as read (resets unreadCount to 0).
  Future<void> markThreadRead({
    required String postId,
    required String threadUserId,
  }) async {
    try {
      await _threadsRef(postId).doc(threadUserId).update({'unreadCount': 0});
    } catch (e) {
      debugPrint("Error marking thread read: $e");
    }
  }
}
