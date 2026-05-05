import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';
import '../../../services/database_service.dart';
import 'glimpse_viewer_screen.dart';

class GlimpsCard extends StatelessWidget {
  final PostModel glimpse;
  final UserModel? user;
  final List<PostModel> allGlimpses;
  final int glimpseIndex;

  final Map<String, List<PostModel>> groupedGlimpses;
  final List<String> authorIds;
  final int initialAuthorIndex;

  const GlimpsCard({
    super.key,
    required this.glimpse,
    required this.user,
    this.allGlimpses = const [],
    this.glimpseIndex = 0,
    this.groupedGlimpses = const {},
    this.authorIds = const [],
    this.initialAuthorIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (glimpse.imagePaths.isEmpty && glimpse.coverImagePath == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Prioritize coverImagePath (for video glimpses) to avoid crashing on .mp4 URLs
    final thumbnailPath =
        glimpse.coverImagePath ??
        (glimpse.imagePaths.isNotEmpty ? glimpse.imagePaths.first : '');

    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        if (user != null) {
          openGlimpseViewer(
            context,
            groupedGlimpses: groupedGlimpses.isNotEmpty ? groupedGlimpses : {user!.id: [glimpse]},
            authorIds: authorIds.isNotEmpty ? authorIds : [user!.id],
            initialAuthorIndex: initialAuthorIndex,
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
                      thumbnailPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.white54),
                        ),
                      ),
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
              Positioned(
                bottom: 12,
                left: 10,
                right: 10,
                child: user != null
                    ? _buildUserInfo(user!)
                    : FutureBuilder<Map<String, dynamic>?>(
                        future: DatabaseService.instance.getUserProfile(
                          glimpse.authorId,
                          useCache: true,
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final realUser = UserModel.fromMap(
                            snapshot.data!,
                            glimpse.authorId,
                          );
                          return _buildUserInfo(realUser);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(UserModel u) {
    ImageProvider avatarProvider;
    if (u.avatarAsset != null && u.avatarAsset!.isNotEmpty) {
      if (u.avatarAsset!.startsWith('http')) {
        avatarProvider = NetworkImage(u.avatarAsset!);
      } else {
        avatarProvider = AssetImage(u.avatarAsset!);
      }
    } else {
      avatarProvider = const AssetImage('assets/reaction_default.png');
    }

    return Column(
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
                border: Border.all(color: Colors.white, width: 1.5),
                image: DecorationImage(
                  image: avatarProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Name
            Expanded(
              child: Text(
                u.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
