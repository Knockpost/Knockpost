import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<List<ChatModel>> getChats() {
    if (currentUserId == null) return const Stream.empty();
    
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.data());
      }).toList();
    });
  }

  Future<void> sendMessage(String chatId, String text) async {
    final userId = currentUserId;
    if (userId == null) return;

    final message = {
      'text': text,
      'senderId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    // Update the last message in the chat document
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
    });
  }
}
