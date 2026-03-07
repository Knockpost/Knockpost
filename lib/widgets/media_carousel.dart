import 'package:flutter/material.dart';

class MediaCarousel extends StatelessWidget {
  const MediaCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        "assets/test1.jpg",
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}