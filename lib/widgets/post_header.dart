import 'package:flutter/material.dart';

class PostHeader extends StatelessWidget {
  const PostHeader({super.key});

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [

        const CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey,
        ),

        const SizedBox(width:10),

        const Expanded(
          child: Text(
            "username",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
              horizontal:10,
              vertical:4
          ),

          decoration: BoxDecoration(
            color: const Color(0xfff2f2f2),
            borderRadius: BorderRadius.circular(18),
          ),

          child: const Text(
            "Knock",
            style: TextStyle(
              fontSize:12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width:8),

        const Icon(Icons.more_horiz)

      ],
    );
  }
}