import 'package:flutter/material.dart';

class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key});

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [

        Container(
          height:40,
          width:40,

          decoration: BoxDecoration(
            color: const Color(0xfff2f2f2),
            borderRadius: BorderRadius.circular(12),
          ),

          child: Center(
            child: Image.asset(
              "assets/reaction_default.png",
              width:22,
            ),
          ),

        ),

        const SizedBox(width:10),

        Container(
          height:40,
          width:40,

          decoration: BoxDecoration(
            color: const Color(0xfff2f2f2),
            borderRadius: BorderRadius.circular(12),
          ),

          child: const Icon(
            Icons.chat_bubble_outline,
            size:20,
            color: Colors.black54,
          ),

        ),

        const SizedBox(width:10),

        const Icon(
          Icons.share_outlined,
          color: Colors.black,
        )

      ],
    );
  }
}