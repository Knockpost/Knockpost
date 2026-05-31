import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/reply_thread.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import 'chat_logger.dart';
import 'performance_service.dart';

class CommentService {
  CommentService._internal();
  static final CommentService instance = CommentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Stream cache ──────────────────────────────────────────────────────
  // Prevents creating a new Firestore listener every time the widget rebuilds
  // (e.g. keyboard open/close, text input, setState). Without this, each
  // rebuild destroys the old snapshot listener and creates a new one, causing
  // momentary data loss and "ghost" empty states.
  final Map<String, Stream<List<ReplyThread>>> _threadStreamCache = {};
  final Map<String, Stream<List<ReplyMessage>>> _messageStreamCache = {};

  // ── Collection references ─────────────────────────────────────────────

  CollectionReference _threadsRef(String postId) =>
      _firestore.collection('posts').doc(postId).collection('threads');

  CollectionReference _messagesRef(String postId, String threadUserId) =>
      _threadsRef(postId).doc(threadUserId).collection('messages');

  // ── Stream: threads for a post ────────────────────────────────────────

  /// Streams the list of reply threads for a post.
  /// If [isPostOwner] is true, it returns all threads for this post.
  /// If false, it returns only the thread belonging to the current user.
  ///
  /// Streams are cached by a composite key so that repeated calls from
  /// widget rebuilds reuse the same underlying Firestore listener.
  Stream<List<ReplyThread>> getThreadsForPost({
    required String postId,
    required String currentUserId,
    required bool isPostOwner,
  }) {
    final cacheKey = '$postId::$currentUserId::$isPostOwner';

    if (_threadStreamCache.containsKey(cacheKey)) {
      PerformanceService.instance.incrementPrivateReplyStreamCacheHit();
      PerformanceService.instance.incrementPrivateReplyStreamReuse();
    } else {
      PerformanceService.instance.incrementPrivateReplyStreamCacheMiss();
    }

    return _threadStreamCache.putIfAbsent(cacheKey, () {
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
      }).asBroadcastStream();
    });
  }

  // ── Stream: messages for a thread ─────────────────────────────────────

  /// Streams the messages within a specific thread.
  ///
  /// Cached so that PageView page switches / widget rebuilds don't
  /// tear down and recreate the listener.
  Stream<List<ReplyMessage>> getMessagesForThread({
    required String postId,
    required String threadUserId,
  }) {
    final cacheKey = '$postId::$threadUserId';

    if (_messageStreamCache.containsKey(cacheKey)) {
      PerformanceService.instance.incrementPrivateReplyStreamCacheHit();
      PerformanceService.instance.incrementPrivateReplyStreamReuse();
    } else {
      PerformanceService.instance.incrementPrivateReplyStreamCacheMiss();
    }

    return _messageStreamCache.putIfAbsent(cacheKey, () {
      return _messagesRef(postId, threadUserId)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ReplyMessage.fromMap(
              doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      }).asBroadcastStream();
    });
  }

  /// Disposes streams only for the given [postId] to preserve active
  /// caches on global / persistent feeds while freeing up memory
  /// for the dismissed sheet.
  void disposePostStreams(String postId) {
    int disposedCount = 0;
    
    _threadStreamCache.removeWhere((key, _) {
      if (key.startsWith('$postId::')) {
        disposedCount++;
        return true;
      }
      return false;
    });

    _messageStreamCache.removeWhere((key, _) {
      if (key.startsWith('$postId::')) {
        disposedCount++;
        return true;
      }
      return false;
    });

    for (var i = 0; i < disposedCount; i++) {
      PerformanceService.instance.incrementPrivateReplyStreamDisposal();
    }
  }

  // ── Send message (batch write — works offline) ────────────────────────

  /// Sends a private reply message using a Firestore **batch write** instead
  /// of a transaction.
  ///
  /// **Why batch instead of transaction?**
  /// Firestore transactions require a network roundtrip to read the current
  /// state before writing. If the device is offline, the transaction
  /// immediately fails with a timeout — causing silent message loss.
  /// Batch writes, on the other hand, are queued locally by Firestore's
  /// offline persistence and committed atomically when the network returns.
  ///
  /// **Deduplication:** A locally generated [clientId] is used as the
  /// Firestore document ID for the message. If the same send is retried
  /// (e.g. after a connectivity blip), the second write is an idempotent
  /// overwrite of the same document, preventing duplicate messages.
  Future<void> sendMessage({
    required String postId,
    required String postAuthorId,
    required String senderId,
    required String threadUserId,
    required String text,
    String? clientId,
    String? postThumbnailUrl,
  }) async {
    try {
      final now = FieldValue.serverTimestamp();
      final receiverId =
          senderId == postAuthorId ? threadUserId : postAuthorId;

      // Use clientId as doc ID for deduplication; fall back to auto-ID
      final msgDocId =
          clientId ?? _messagesRef(postId, threadUserId).doc().id;
      final messageRef = _messagesRef(postId, threadUserId).doc(msgDocId);
      final threadRef = _threadsRef(postId).doc(threadUserId);

      final batch = _firestore.batch();

      // Set message document
      batch.set(messageRef, {
        'senderId': senderId,
        'receiverId': receiverId,
        'postId': postId,
        'text': text,
        'timestamp': now,
        'clientId': msgDocId,
      });

      // Upsert thread metadata
      // We use FieldValue.increment for unreadCount when the sender is NOT
      // the post author. When the author replies, we reset unread to 0.
      final threadData = <String, dynamic>{
        'postId': postId,
        'authorId': postAuthorId,
        'userId': threadUserId,
        'lastMessage': text,
        'lastTimestamp': now,
      };

      if (senderId == postAuthorId) {
        // When post owner replies, reset owner unread, increment user unread
        threadData['ownerUnreadCount'] = 0;
        threadData['userUnreadCount'] = FieldValue.increment(1);
        
        PerformanceService.instance.incrementPrivateReplyUserUnreadUpdates();
      } else {
        // When thread user replies, reset user unread, increment owner unread
        threadData['userUnreadCount'] = 0;
        threadData['ownerUnreadCount'] = FieldValue.increment(1);
        
        PerformanceService.instance.incrementPrivateReplyOwnerUnreadUpdates();
      }

      batch.set(threadRef, threadData, SetOptions(merge: true));

      // ── Notification: single write, no duplicates ──
      // postThumbnailUrl is now passed directly from the UI to preserve offline batch queuing
      // and eliminate 1:1 post document duplicate reads.
      if (senderId != receiverId) {

        NotificationService.instance.sendNotificationInBatch(
          batch,
          receiverUid: receiverId,
          type: NotificationType.comment,
          postId: postId,
          commentSnippet: text,
          postThumbnailUrl: postThumbnailUrl,
        );
      }

      await batch.commit();

      ChatLogger.instance.info('Reply', 'sent postId=$postId threadUser=$threadUserId msgId=$msgDocId');
    } catch (e) {
      ChatLogger.instance.error('Reply', 'send failed', e);
      rethrow;
    }
  }

  /// Wrapper with automatic retry for transient failures.
  Future<void> sendMessageWithRetry({
    required String postId,
    required String postAuthorId,
    required String senderId,
    required String threadUserId,
    required String text,
    String? postThumbnailUrl,
    int maxRetries = 2,
  }) async {
    final clientId =
        '${senderId}_${DateTime.now().millisecondsSinceEpoch}';

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await sendMessage(
          postId: postId,
          postAuthorId: postAuthorId,
          senderId: senderId,
          threadUserId: threadUserId,
          text: text,
          clientId: clientId,
          postThumbnailUrl: postThumbnailUrl,
        );
        return; // Success
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        // Exponential backoff: 500ms, 1500ms
        await Future.delayed(
            Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }

  // ── Mark thread as read ───────────────────────────────────────────────

  /// Marks a thread as read (resets unreadCount to 0).
  /// Uses set-with-merge so the operation succeeds even if the
  /// thread document doesn't exist yet (race condition where the
  /// post owner opens a thread before the first message is committed).
  Future<void> markThreadRead({
    required String postId,
    required String threadUserId,
    required bool isPostOwner,
  }) async {
    try {
      final fieldToReset = isPostOwner ? 'ownerUnreadCount' : 'userUnreadCount';
      await _threadsRef(postId).doc(threadUserId).set(
        {fieldToReset: 0},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint("Error marking thread read: $e");
    }
  }
}
