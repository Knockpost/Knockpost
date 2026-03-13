import 'package:flutter/material.dart';
import 'message_info_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  void showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            children: const [
              AttachmentItem(icon: Icons.camera_alt, label: "Camera"),

              AttachmentItem(icon: Icons.photo, label: "Gallery"),

              AttachmentItem(icon: Icons.videocam, label: "Video"),

              AttachmentItem(icon: Icons.insert_drive_file, label: "File"),

              AttachmentItem(icon: Icons.music_note, label: "Audio"),

              AttachmentItem(icon: Icons.location_on, label: "Location"),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xfff5f7fb),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),

        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MessageInfoScreen(),
              ),
            );
          },

          child: Row(
            children: const [
              CircleAvatar(
                radius: 18,
                backgroundImage: AssetImage("assets/test1.jpg"),
              ),

              SizedBox(width: 10),

              Text(
                "Emma Brown",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),

      body: Column(
        children: [
          /// CHAT MESSAGES
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.all(16),
              children: const [
                MessageBubble(text: "Yes sure!", isMe: true),

                MessageBubble(text: "Are we meeting tomorrow?", isMe: false),

                MessageBubble(text: "I'm good! You?", isMe: true),

                MessageBubble(text: "Hi! How are you?", isMe: false),
              ],
            ),
          ),

          /// MESSAGE INPUT
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: Colors.white,

              child: Row(
                children: [
                  /// ATTACHMENT BUTTON
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      showAttachmentMenu(context);
                    },
                  ),

                  /// TEXT FIELD
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        filled: true,
                        fillColor: const Color(0xfff1f1f1),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  /// VOICE BUTTON
                  IconButton(icon: const Icon(Icons.mic), onPressed: () {}),

                  /// SEND BUTTON
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),

                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const MessageBubble({super.key, required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(16),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class AttachmentItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const AttachmentItem({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blue,

          child: Icon(icon, color: Colors.white),
        ),

        const SizedBox(height: 6),

        Text(label),
      ],
    );
  }
}
