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
              height: MediaQuery.sizeOf(context).width * 0.60 * (16 / 9),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: allGlimpses.length,
                itemBuilder: (context, index) {
                  final glimpse = allGlimpses[index];
                  final currentUser = CurrentUserService.instance.currentUser;
                  
                  if (currentUser != null && glimpse.authorId == currentUser.id) {
                    return GlimpsCard(
                      glimpse: glimpse,
                      user: currentUser,
                      allGlimpses: allGlimpses,
                      glimpseIndex: index,
                    );
                  }

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: DatabaseService.instance.getUserProfile(glimpse.authorId, useCache: true),
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      final author = data != null
                          ? UserModel.fromMap(data, glimpse.authorId)
                          : UserModel(id: glimpse.authorId, displayName: 'Loading...', username: '...');

                      return GlimpsCard(
                        glimpse: glimpse,
                        user: author,
                        allGlimpses: allGlimpses,
                        glimpseIndex: index,
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
