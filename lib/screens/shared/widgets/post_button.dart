import 'package:flutter/material.dart';

class PostButton extends StatelessWidget {
  final VoidCallback onPost;

  const PostButton({super.key, required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: onPost,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        child: const Text(
          "Post",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
