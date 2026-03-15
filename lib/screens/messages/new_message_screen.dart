import 'package:flutter/material.dart';
import 'chat_screen.dart';

class NewMessageScreen extends StatelessWidget {
  const NewMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("New Message", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Column(
        children: [
          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),

            child: TextField(
              decoration: InputDecoration(
                hintText: "Search users",

                prefixIcon: const Icon(Icons.search),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          /// USER LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),

              // ignore: prefer_const_literals_to_create_immutables
              children: [
                // ignore: prefer_const_constructors
                UserTile(name: "John Doe"),
                // ignore: prefer_const_constructors
                UserTile(name: "Sarah Wilson"),
                // ignore: prefer_const_constructors
                UserTile(name: "Alex Brown"),
                // ignore: prefer_const_constructors
                UserTile(name: "Emma Smith"),
                // ignore: prefer_const_constructors
                UserTile(name: "Michael Clark"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  final String name;

  const UserTile({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),

        child: ListTile(
          leading: const CircleAvatar(
            backgroundImage: AssetImage("assets/test1.jpg"),
          ),

          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }
}
