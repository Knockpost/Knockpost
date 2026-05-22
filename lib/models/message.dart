import 'package:cloud_firestore/cloud_firestore.dart';

/// Delivery status for a private reply message.
enum ReplyMessageStatus { sending, sent, failed }

class ReplyMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String postId;
  final String text;
  final DateTime timestamp;

  /// Locally generated unique ID used for idempotent deduplication.
  /// If the network drops after a write, retrying with the same clientId
  /// guarantees no duplicate messages are created in Firestore.
  final String? clientId;

  /// Tracks optimistic UI state. Only used locally — never persisted.
  final ReplyMessageStatus status;

  const ReplyMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.postId,
    required this.text,
    required this.timestamp,
    this.clientId,
    this.status = ReplyMessageStatus.sent,
  });

  ReplyMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? postId,
    String? text,
    DateTime? timestamp,
    String? clientId,
    ReplyMessageStatus? status,
  }) {
    return ReplyMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      postId: postId ?? this.postId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'postId': postId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      if (clientId != null) 'clientId': clientId,
    };
  }

  /// Safely parses Firestore timestamps.
  /// When a document has `FieldValue.serverTimestamp()` that hasn't resolved
  /// yet (e.g. offline write), the field comes back as `null`. Instead of
  /// falling back to `DateTime.now()` (which causes ordering flicker), we
  /// use epoch-0 as a sentinel so the message stays at a stable position
  /// until the server timestamp arrives.
  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    // null or unknown → use current time (close to server time, avoids "Jan 1" flash)
    return DateTime.now();
  }

  factory ReplyMessage.fromMap(Map<String, dynamic> map, String documentId) {
    return ReplyMessage(
      id: documentId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      postId: map['postId'] ?? '',
      text: map['text'] ?? '',
      timestamp: _parseTimestamp(map['timestamp']),
      clientId: map['clientId'] as String?,
      status: ReplyMessageStatus.sent,
    );
  }
}
