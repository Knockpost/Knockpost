import 'package:flutter/material.dart';

class MessageInfoScreen extends StatelessWidget {
  const MessageInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),

      appBar: AppBar(title: const Text("Chat Info")),

      body: Column(
        children: [
          const SizedBox(height: 20),

          /// USER PROFILE
          const CircleAvatar(
            radius: 45,
            backgroundImage: AssetImage("assets/test1.jpg"),
          ),

          const SizedBox(height: 10),

          const Text(
            "Emma Brown",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 25),

          /// OPTIONS
          _buildOption(
            icon: Icons.notifications_off,
            text: "Mute Notifications",
          ),

          _buildOption(icon: Icons.photo, text: "Shared Media"),

          _buildOption(icon: Icons.block, text: "Block User"),

          _buildOption(
            icon: Icons.report,
            text: "Report User",
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String text,
    Color color = Colors.black,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
      onTap: () {},
    );
  }
}
