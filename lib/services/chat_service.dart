import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';

/// Handles all 1:1 messaging logic backed by Firestore.
///
/// Firestore schema:
///   chats/{chatId}
///     participants      : [uid1, uid2]
///     lastMessage       : string
///     lastMessageTime   : Timestamp
///     lastSenderId      : string
///     unreadCount       : { uid1: int, uid2: int }
///
///   chats/{chatId}/messages/{msgId}
///     senderId  : string
///     text      : string
///     timestamp : Timestamp
///     replyToId : string?
///     seen      : bool
///     imageUrl  : string?
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _myUid => AuthService.instance.currentUser?.uid;
  CollectionReference get _chats => _db.collection('chats');

  // ── Chat ID ────────────────────────────────────────────────────────────────

  /// Generates a stable chatId by sorting the two UIDs alphabetically.
  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Stream of all chat rooms that the current user is a participant in,
  /// sorted by last message time descending.
  Stream<List<ChatRoom>> streamUserChats() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    return _chats
        .where('participants', arrayContains: me)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                ChatRoom.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Stream of messages for a given chat, ordered newest first (reverse=true for ListView).
  Stream<List<ChatMessage>> streamMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                ChatMessage.fromMap(d.data(), d.id))
            .toList());
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  /// Sends a message to [otherUid].
  /// Creates the chat room if it doesn't exist yet.
  Future<void> sendMessage({
    required String otherUid,
    required String text,
    String? replyToId,
    String? imageUrl,
  }) async {
    final me = _myUid;
    if (me == null) return;

    final chatId = getChatId(me, otherUid);
    final chatRef = _chats.doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    try {
      await _db.runTransaction((txn) async {
        final chatSnap = await txn.get(chatRef);

        // Build the message payload
        final msgData = <String, dynamic>{
          'senderId': me,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'seen': false,
          if (replyToId != null) 'replyToId': replyToId,
          if (imageUrl != null) 'imageUrl': imageUrl,
        };

        // Write the message
        txn.set(msgRef, msgData);

        if (!chatSnap.exists) {
          // Create the chat room
          txn.set(chatRef, {
            'participants': [me, otherUid],
            'lastMessage': text,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': me,
            'unreadCount': {otherUid: 1, me: 0},
          });
        } else {
          // Update the existing chat room
          final existing = chatSnap.data() as Map<String, dynamic>;
          final unread = Map<String, dynamic>.from(
              (existing['unreadCount'] as Map<String, dynamic>?) ?? {});
          unread[otherUid] = ((unread[otherUid] as int?) ?? 0) + 1;
          unread[me] = 0;
          txn.update(chatRef, {
            'lastMessage': text,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': me,
            'unreadCount': unread,
          });
        }
      });
    } catch (e) {
      debugPrint('ChatService.sendMessage error: $e');
      rethrow;
    }
  }

  // ── Mark as Read ──────────────────────────────────────────────────────────

  /// Resets unread count for the current user to 0.
  /// Also marks all unseen messages from the other user as seen.
  Future<void> markChatAsRead(String chatId) async {
    final me = _myUid;
    if (me == null) return;
    try {
      // Reset unread count
      await _chats.doc(chatId).update({'unreadCount.$me': 0});

      // Mark unseen incoming messages as seen
      final unseenSnap = await _chats
          .doc(chatId)
          .collection('messages')
          .where('seen', isEqualTo: false)
          .where('senderId', isNotEqualTo: me)
          .get();

      final batch = _db.batch();
      for (final doc in unseenSnap.docs) {
        batch.update(doc.reference, {'seen': true});
      }
      if (unseenSnap.docs.isNotEmpty) await batch.commit();
    } catch (e) {
      debugPrint('ChatService.markChatAsRead error: $e');
    }
  }

  // ── Delete message ─────────────────────────────────────────────────────────

  /// Deletes a single message. Only the sender should be able to delete.
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _chats.doc(chatId).collection('messages').doc(messageId).delete();
    } catch (e) {
      debugPrint('ChatService.deleteMessage error: $e');
    }
  }
}
