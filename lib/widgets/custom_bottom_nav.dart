// widgets/custom_bottom_nav.dart

import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final selectedColor = isDark ? Colors.white : Colors.black;
    final unselectedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;

    Color _getColor(int index) {
      return currentIndex == index ? selectedColor : unselectedColor;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 50, // Fixed height to match Instagram exactly
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // HOME
              GestureDetector(
                onTap: () => onTap(0),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    currentIndex == 0 ? Icons.home_filled : Icons.home_outlined,
                    size: 30,
                    color: _getColor(0),
                  ),
                ),
              ),

              // SEARCH
              GestureDetector(
                onTap: () => onTap(1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.search,
                    size: 30,
                    color: _getColor(1),
                    weight: currentIndex == 1 ? 700 : 400,
                  ),
                ),
              ),

              // VIDEO / REELS (Like Substacks distinct video icon)
              GestureDetector(
                onTap: () => onTap(2),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    currentIndex == 2 ? Icons.movie_rounded : Icons.movie_outlined,
                    size: 30,
                    color: _getColor(2),
                  ),
                ),
              ),

              // CHAT / MESSAGES
              GestureDetector(
                onTap: () => onTap(3),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    currentIndex == 3 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                    size: 28,
                    color: _getColor(3),
                  ),
                ),
              ),

              // PROFILE
              GestureDetector(
                onTap: () => onTap(4),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    currentIndex == 4 ? Icons.person : Icons.person_outline,
                    size: 30,
                    color: _getColor(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}