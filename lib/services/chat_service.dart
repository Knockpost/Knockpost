import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'chat_logger.dart';
import 'message_retry_queue.dart';

class SendResult {
  final String messageId;
  final MessageStatus status;
  SendResult(this.messageId, this.status);
}

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final math.Random _random = math.Random();

  String? get _myUid => AuthService.instance.currentUser?.uid;
  CollectionReference get _chats => _db.collection('chats');

  // Stream caching — only for chat rooms (shared across screens)
  Stream<List<ChatRoom>>? _chatRoomsStream;

  // ── Chat ID ────────────────────────────────────────────────────────────────

  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<ChatRoom>> streamUserChats() {
    final me = _myUid;
    if (me == null) {
      ChatLogger.instance.warning('streamUserChats', 'Called with null uid');
      return const Stream.empty();
    }
    
    _chatRoomsStream ??= _chats
        .where('participants', arrayContains: me)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ChatRoom.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      list.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    }).asBroadcastStream();

    return _chatRoomsStream!;
  }

  /// Returns a **fresh** stream each time it is called.
  /// Each ChatScreen creates its own Firestore snapshot listener via
  /// `initState` and cancels it in `dispose`. Caching broadcast streams
  /// caused stale-stream bugs: the cached broadcast would stop emitting
  /// after the first subscriber cancelled, leaving subsequent screens
  /// stuck on the loading spinner.
  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = 50}) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) {
            return ChatMessage.fromMap(d.data(), d.id);
          }).toList();
        });
  }

  void clearStreamCache() {
    _chatRoomsStream = null;
    ChatLogger.instance.info('StreamCache', 'Cleared stream caches');
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<SendResult> sendMessageWithRetry({
    required String otherUid,
    required String text,
    String? replyToId,
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
  }) async {
    final me = _myUid;
    if (me == null) throw Exception('Cannot send message: User is not authenticated');

    // Unique ID for deduplication
    final clientId = 'client_${me}_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(100000)}';
    
    try {
      final msgId = await _sendMessageInternal(
        otherUid: otherUid,
        text: text,
        replyToId: replyToId,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        audioDuration: audioDuration,
        clientId: clientId,
      );
      return SendResult(msgId, MessageStatus.sent);
    } catch (e) {
      ChatLogger.instance.warning('sendMessageWithRetry', 'Send failed, queuing for retry: $e');
      MessageRetryQueue.instance.enqueue(clientId, () async {
        await _sendMessageInternal(
          otherUid: otherUid,
          text: text,
          replyToId: replyToId,
          imageUrl: imageUrl,
          audioUrl: audioUrl,
          audioDuration: audioDuration,
          clientId: clientId,
        );
      });
      return SendResult(clientId, MessageStatus.sending); // Return client ID as temp ID
    }
  }

  // Keep legacy method for compatibility if needed, but internally map it
  Future<void> sendMessage({
    required String otherUid,
    required String text,
    String? replyToId,
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
  }) async {
    await sendMessageWithRetry(
      otherUid: otherUid,
      text: text,
      replyToId: replyToId,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
    );
  }

  Future<String> _sendMessageInternal({
    required String otherUid,
    required String text,
    String? replyToId,
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
    required String clientId,
  }) async {
    final me = _myUid;
    if (me == null) {
      throw Exception('Cannot send message: User is not authenticated');
    }

    final chatId = getChatId(me, otherUid);
    final chatRef = _chats.doc(chatId);
    
    // Use clientId as doc ID → retries overwrite the same doc (idempotent dedup)
    // No blocking network query needed.
    final msgRef = chatRef.collection('messages').doc(clientId);

    final batch = _db.batch();

    final msgData = <String, dynamic>{
      'senderId': me,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
      'status': MessageStatus.sent.name,
      'clientId': clientId,
      if (replyToId != null) 'replyToId': replyToId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (audioDuration != null) 'audioDuration': audioDuration,
    };

    batch.set(msgRef, msgData);

    // Upsert chat room metadata using set-with-merge
    // This works whether the chat doc exists or not, no read needed.
    String snippet = text;
    if (snippet.isEmpty) {
      if (audioUrl != null) { snippet = '🎙 Audio message'; }
      else if (imageUrl != null) { snippet = '📷 Image'; }
    }

    batch.set(chatRef, {
      'participants': [me, otherUid],
      'lastMessage': snippet,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': me,
      'unreadCount': {otherUid: FieldValue.increment(1), me: 0},
    }, SetOptions(merge: true));

    // Add notification creation to the SAME batch so it triggers the Cloud Function instantly
    NotificationService.instance.sendNotificationInBatch(
      batch,
      receiverUid: otherUid,
      type: NotificationType.message,
      commentSnippet: text,
    );

    await batch.commit();
    
    return msgRef.id;
  }

  // ── Mark as Read ──────────────────────────────────────────────────────────

  Future<void> markChatAsRead(String chatId) async {
    final me = _myUid;
    if (me == null) return;
    try {
      await _chats.doc(chatId).update({'unreadCount.$me': 0});

      // Batch mark as read, max 500 per batch
      final unseenSnap = await _chats
          .doc(chatId)
          .collection('messages')
          .where('seen', isEqualTo: false)
          .where('senderId', isNotEqualTo: me)
          .limit(500)
          .get();

      if (unseenSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unseenSnap.docs) {
        batch.update(doc.reference, {'seen': true});
      }
      await batch.commit();
      
      ChatLogger.instance.info('markChatAsRead', 'Marked ${unseenSnap.docs.length} messages as read');
    } catch (e, stack) {
      ChatLogger.instance.error('markChatAsRead', 'Error marking chat as read', e, stack);
    }
  }

  // ── Delete message ─────────────────────────────────────────────────────────

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _chats.doc(chatId).collection('messages').doc(messageId).delete();
      
      // Update last message if needed (simplified: just fetch the newest message)
      final latest = await _chats.doc(chatId).collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
        
      if (latest.docs.isNotEmpty) {
        final data = latest.docs.first.data();
        await _chats.doc(chatId).update({
          'lastMessage': data['text'] ?? '',
          'lastMessageTime': data['timestamp'],
          'lastSenderId': data['senderId'],
        });
      } else {
        await _chats.doc(chatId).update({
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': '',
        });
      }
      
      ChatLogger.instance.info('deleteMessage', 'Deleted message $messageId');
    } catch (e, stack) {
      ChatLogger.instance.error('deleteMessage', 'Error deleting message', e, stack);
    }
  }
}
