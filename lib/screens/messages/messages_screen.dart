import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewMessageScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  hintText: "Search",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          /// MESSAGE LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                MessageTile(
                  name: "John Doe",
                  message: "Just finished work, what's up?",
                  time: "2m",
                ),
                MessageTile(
                  name: "Jane Doe",
                  message: "That sounds awesome! 😉",
                  time: "10m",
                ),
                MessageTile(
                  name: "Alex Smith",
                  message: "Are we still on for tomorrow?",
                  time: "30m",
                ),
                MessageTile(
                  name: "Emily Brown",
                  message: "Sure, I'll send it over to you!",
                  time: "45m",
                ),
                MessageTile(
                  name: "Daniel Lee",
                  message: "Can you call me when you're free?",
                  time: "1h",
                ),
                MessageTile(
                  name: "Sarah Wilson",
                  message: "Haha that's so funny!",
                  time: "2h",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;

  const MessageTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(
            userName: name,
            userAvatar: "assets/test1.jpg",
            userUsername: "@${name.replaceAll(' ', '').toLowerCase()}",
          )),
        );
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffe8f0ff), Color(0xfffff3e8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),

        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundImage: AssetImage("assets/test1.jpg"),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(message, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                time,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
