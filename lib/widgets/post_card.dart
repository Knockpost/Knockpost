import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key});

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const SizedBox(height: 16),

        /// USER INFO
        // ignore: prefer_const_constructors
        ListTile(
          leading: const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey,
          ),
          title: const Text(
            "username",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.more_horiz),
        ),

        /// POST IMAGE
        Container(
          height: 300,
          color: Colors.grey[300],
        ),

        const SizedBox(height: 12),

        /// CAPTION
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "This is a Knockpost caption.",
            style: TextStyle(fontSize: 14),
          ),
        ),

        const SizedBox(height: 16),

      ],
    );
  }
}