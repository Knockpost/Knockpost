import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/haptic_helper.dart';

class ReactorsSheet extends StatelessWidget {
  final String postId;

  const ReactorsSheet({super.key, required this.postId});

  static void show(BuildContext context, {required String postId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReactorsSheet(postId: postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Dummy reactors for demo
    final List<Map<String, dynamic>> reactors = [
      {'user': demoZaynMalik, 'reaction': '👍'},
      {'user': demoJustinBieber, 'reaction': '❤️'},
      {'user': demoSaptarshiNayak, 'reaction': '🔥'},
      {'user': demoAryaLayek, 'reaction': '🥰'},
      {'user': demoLeonardoDiCaprio, 'reaction': '😮'},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Reactions",
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reactors.length,
              itemBuilder: (context, index) {
                final reactor = reactors[index];
                final UserModel user = reactor['user'];
                final String reaction = reactor['reaction'];

                return InkWell(
                  onTap: () {
                    KnockHaptics.selection();
                    // Navigate to profile (already implemented in many places)
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: user.avatarAsset != null
                                  ? AssetImage(user.avatarAsset!)
                                  : null,
                              child: user.avatarAsset == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: bgColor, width: 2),
                                ),
                                child: Text(
                                  reaction,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.username,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.displayName,
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Profile",
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
