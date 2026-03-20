import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String text;
  final String senderId;
  final DateTime timestamp;

  MessageModel({
    required this.text,
    required this.senderId,
    required this.timestamp,
  });

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    return MessageModel(
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
