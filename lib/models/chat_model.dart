import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus {
  sending,
  sent,
  delivered,
  failed,
}

/// A single chat message inside a conversation.
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String? replyToId;
  final bool seen;
  final String? imageUrl;
  final MessageStatus status;
  final String? clientId;
  final bool hasPendingWrites;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.replyToId,
    this.seen = false,
    this.imageUrl,
    this.status = MessageStatus.sent,
    this.clientId,
    this.hasPendingWrites = false,
  });

  bool get isImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isPending => status == MessageStatus.sending || hasPendingWrites;

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId, {bool hasPendingWrites = false}) {
    DateTime parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
      // Use current time for pending writes — close enough to server time, avoids "Jan 1" flash
      return DateTime.now();
    }

    MessageStatus parseStatus(String? statusStr) {
      switch (statusStr) {
        case 'sending': return MessageStatus.sending;
        case 'sent': return MessageStatus.sent;
        case 'delivered': return MessageStatus.delivered;
        case 'failed': return MessageStatus.failed;
        default: return MessageStatus.sent;
      }
    }

    return ChatMessage(
      id: docId,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: parseTimestamp(map['timestamp']),
      replyToId: map['replyToId'] as String?,
      seen: map['seen'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
      status: parseStatus(map['status'] as String?),
      clientId: map['clientId'] as String?,
      hasPendingWrites: hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        if (replyToId != null) 'replyToId': replyToId,
        'seen': seen,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'status': status.name,
        if (clientId != null) 'clientId': clientId,
      };
}

/// Inbox entry representing a conversation between two users.
class ChatRoom {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastSenderId;
  final Map<String, int> unreadCount;

  const ChatRoom({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastSenderId,
    required this.unreadCount,
  });

  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  /// Returns the UID of the other participant (not `myUid`).
  String otherUid(String myUid) =>
      participants.firstWhere((p) => p != myUid, orElse: () => '');

  factory ChatRoom.fromMap(Map<String, dynamic> map, String docId) {
    final rawUnread = map['unreadCount'] as Map<String, dynamic>? ?? {};
    return ChatRoom(
      chatId: docId,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime:
          (map['lastMessageTime'] as Timestamp?)?.toDate(),
      lastSenderId: map['lastSenderId'] as String? ?? '',
      unreadCount:
          rawUnread.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}
