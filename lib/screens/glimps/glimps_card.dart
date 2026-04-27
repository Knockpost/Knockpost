import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';
import 'glimpse_viewer_screen.dart';

class GlimpsCard extends StatelessWidget {
  final PostModel glimpse;
  final UserModel? user;
  final List<PostModel> allGlimpses;
  final int glimpseIndex;

  const GlimpsCard({
    super.key,
    required this.glimpse,
    required this.user,
    this.allGlimpses = const [],
    this.glimpseIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (glimpse.imagePaths.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // We mock the video thumbnail with the first image path
    final thumbnailPath = glimpse.imagePaths.first;

    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        if (user != null) {
          final glimpses = allGlimpses.isNotEmpty ? allGlimpses : [glimpse];
          openGlimpseViewer(
            context,
            glimpses: glimpses,
            user: user!,
            initialIndex: glimpseIndex,
            heroTag: 'glimpse_${glimpse.id}',
          );
        }
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.60,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background Thumbnail ──
              thumbnailPath.startsWith('assets/')
                  ? Image.asset(thumbnailPath, fit: BoxFit.cover)
                  : Image.network(
                      thumbnailPath, // Mock networking or file
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.error),
                    ),

              // ── Gradient Overlay ──
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
              ),


              // ── User Info (Bottom) ──
              if (user != null)
                Positioned(
                  bottom: 12,
                  left: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              image: DecorationImage(
                                image:
                                    user!.avatarAsset != null &&
                                        user!.avatarAsset!.isNotEmpty
                                    ? AssetImage(user!.avatarAsset!)
                                    : const AssetImage(
                                        'assets/reaction_default.png',
                                      ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Name
                          Expanded(
                            child: Text(
                              user!.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black87, blurRadius: 4),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
