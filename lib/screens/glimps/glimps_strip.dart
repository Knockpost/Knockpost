import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/post_service.dart';
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
                  // Find matching user from our demo data, if available
                  // Otherwise, GlimpsCard will handle fetching the real user
                  UserModel? user;
                  if (glimpse.authorId.isNotEmpty) {
                    user = findDemoUserByUsername('${glimpse.authorId.replaceAll('01', '')}.01') 
                                 ?? findDemoUserByUsername(glimpse.authorId.replaceAll('01', '')) 
                                 ?? allDemoUsers.cast<UserModel?>().firstWhere((u) => u?.id == glimpse.authorId, orElse: () => null);
                  }

                  return GlimpsCard(
                    glimpse: glimpse,
                    user: user,
                    allGlimpses: allGlimpses,
                    glimpseIndex: index,
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
