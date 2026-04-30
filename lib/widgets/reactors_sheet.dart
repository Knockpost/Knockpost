import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../utils/haptic_helper.dart';

import '../services/like_service.dart';
import '../services/current_user_service.dart';
import '../utils/image_helper.dart';

class ReactorsSheet extends StatelessWidget {
  final String postId;
  final String? userReaction;

  const ReactorsSheet({super.key, required this.postId, this.userReaction});

  static void show(BuildContext context, {required String postId, String? userReaction}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReactorsSheet(postId: postId, userReaction: userReaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: LikeService.instance.getPostReactions(postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final reactors = snapshot.data ?? [];
                
                if (reactors.isEmpty) {
                  return Center(
                    child: Text(
                      "No reactions yet",
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  );
                }

                final currentUser = CurrentUserService.instance.currentUser;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: reactors.length,
                  itemBuilder: (context, index) {
                    final reactor = reactors[index];
                    final String userId = reactor['userId'];
                    final String reaction = reactor['reaction'] ?? '❤';
                    
                    UserModel user;
                    if (userId == currentUser?.id) {
                      user = currentUser!;
                    } else {
                      user = UserModel(
                        id: userId,
                        username: 'user_${userId.length > 4 ? userId.substring(0, 4) : userId}',
                        displayName: 'Knockpost User',
                      );
                    }

                    return InkWell(
                      onTap: () {
                        KnockHaptics.selection();
                        Navigator.pop(context);
                        if (!user.isOwnProfile) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtherProfileScreen(
                                user: user,
                                posts: const [],
                              ),
                            ),
                          );
                        }
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
                                  backgroundImage: ImageHelper.resolveAvatar(user.avatarAsset),
                                  child: user.avatarAsset == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -2,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: bgColor, width: 2.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      reaction,
                                      style: const TextStyle(fontSize: 12, height: 1.1),
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
