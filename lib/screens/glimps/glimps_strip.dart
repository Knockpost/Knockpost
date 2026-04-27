import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import 'glimps_card.dart';

class GlimpsStrip extends StatelessWidget {
  final List<PostModel> glimpses;

  const GlimpsStrip({
    super.key,
    required this.glimpses,
  });

  @override
  Widget build(BuildContext context) {
    if (glimpses.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            itemCount: glimpses.length,
            itemBuilder: (context, index) {
              final glimpse = glimpses[index];
              // Find matching user from our demo data
              final user = findDemoUserByUsername('${glimpse.authorId.replaceAll('01', '')}.01') 
                           ?? findDemoUserByUsername(glimpse.authorId.replaceAll('01', '')) 
                           ?? allDemoUsers.cast<UserModel?>().firstWhere((u) => u?.id == glimpse.authorId, orElse: () => null);

              return GlimpsCard(
                glimpse: glimpse,
                user: user,
                allGlimpses: glimpses,
                glimpseIndex: index,
              );
            },
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }
}
