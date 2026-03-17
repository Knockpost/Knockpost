import 'package:flutter/material.dart';

class CaptionInput extends StatelessWidget {
  final Function(String) onChanged;

  const CaptionInput({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        maxLines: 4,
        style: const TextStyle(fontSize: 15),
        decoration: const InputDecoration(
          hintText: "Write a caption...",
          border: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }
}