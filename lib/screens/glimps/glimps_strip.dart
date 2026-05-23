import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/post_service.dart';
import '../../../services/current_user_service.dart';
import '../../../services/database_service.dart';
import 'glimps_card.dart';

class GlimpsStrip extends StatelessWidget {
  const GlimpsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<PostModel>>(
      stream: PostService.instance.getGlimpsesStream(),
      builder: (context, snapshot) {
        final allGlimpses = snapshot.data ?? [];

        if (allGlimpses.isEmpty) return const SizedBox.shrink();

        // Group by authorId
        final Map<String, List<PostModel>> groupedGlimpses = {};
        for (final glimpse in allGlimpses) {
          if (!groupedGlimpses.containsKey(glimpse.authorId)) {
            groupedGlimpses[glimpse.authorId] = [];
          }
          groupedGlimpses[glimpse.authorId]!.add(glimpse);
        }

        // Get unique authors list (maintain order of first glimpse appearance)
        final authorIds = groupedGlimpses.keys.toList();

        // Move current user to front if they have glimpses
        final currentUser = CurrentUserService.instance.currentUser;
        if (currentUser != null && authorIds.contains(currentUser.id)) {
          authorIds.remove(currentUser.id);
          authorIds.insert(0, currentUser.id);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Glimpses",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Horizontal Glimpse Carousel ──
            SizedBox(
              height: MediaQuery.sizeOf(context).width * 0.53 * (16 / 9),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: authorIds.length,
                itemBuilder: (context, index) {
                  final authorId = authorIds[index];
                  final userGlimpses = groupedGlimpses[authorId]!;
                  final firstGlimpse = userGlimpses.first;
                  
                  if (currentUser != null && authorId == currentUser.id) {
                    return GlimpsCard(
                      glimpse: firstGlimpse,
                      user: currentUser,
                      allGlimpses: userGlimpses,
                      glimpseIndex: 0,
                      groupedGlimpses: groupedGlimpses,
                      authorIds: authorIds,
                      initialAuthorIndex: index,
                    );
                  }

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: DatabaseService.instance.getUserProfile(authorId, useCache: true),
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      final author = data != null
                          ? UserModel.fromMap(data, authorId)
                          : UserModel(id: authorId, displayName: 'Loading...', username: '...');

                      return GlimpsCard(
                        glimpse: firstGlimpse,
                        user: author,
                        allGlimpses: userGlimpses,
                        glimpseIndex: 0,
                        groupedGlimpses: groupedGlimpses,
                        authorIds: authorIds,
                        initialAuthorIndex: index,
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        );
      }
    );
  }
}
