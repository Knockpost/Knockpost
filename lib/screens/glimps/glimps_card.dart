import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';
import '../../../services/performance_service.dart';
import '../../../services/image_cache_manager.dart';
import '../../../services/user_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'glimpse_viewer_screen.dart';

class GlimpsCard extends StatelessWidget {
  final PostModel glimpse;
  final UserModel? user;
  final List<PostModel> allGlimpses;
  final int glimpseIndex;

  final Map<String, List<PostModel>> groupedGlimpses;
  final List<String> authorIds;
  final int initialAuthorIndex;
  final Map<String, UserModel> preloadedUsers;

  const GlimpsCard({
    super.key,
    required this.glimpse,
    required this.user,
    this.allGlimpses = const [],
    this.glimpseIndex = 0,
    this.groupedGlimpses = const {},
    this.authorIds = const [],
    this.initialAuthorIndex = 0,
    this.preloadedUsers = const {},
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
        
    final optimizedThumbnailPath = 
        glimpse.optimizedCoverImagePath ?? 
        (glimpse.optimizedImagePaths?.isNotEmpty == true ? glimpse.optimizedImagePaths!.first : null);

    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        if (user != null) {
          openGlimpseViewer(
            context,
            groupedGlimpses: groupedGlimpses.isNotEmpty ? groupedGlimpses : {user!.id: [glimpse]},
            authorIds: authorIds.isNotEmpty ? authorIds : [user!.id],
            initialAuthorIndex: initialAuthorIndex,
            preloadedUsers: preloadedUsers.isNotEmpty ? preloadedUsers : {user!.id: user!},
            heroTag: 'glimpse_${glimpse.id}',
          );
        }
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.53,
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
              Builder(builder: (context) {
                if (thumbnailPath.isEmpty) return const SizedBox.shrink();
                
                final isVideoUrl = thumbnailPath.toLowerCase().contains('.mp4') || 
                                   thumbnailPath.toLowerCase().contains('.mov') || 
                                   thumbnailPath.toLowerCase().contains('.mkv') ||
                                   thumbnailPath.toLowerCase().contains('.webm');
                
                if (isVideoUrl) {
                   return _GlimpseVideoThumbnail(path: thumbnailPath);
                }

                Widget buildImage(BoxFit fit) {
                  if (thumbnailPath.startsWith('assets/')) {
                    return Image.asset(thumbnailPath, fit: fit);
                  } else if (thumbnailPath.startsWith('http')) {
                    return CachedNetworkImage(
                      imageUrl: (optimizedThumbnailPath != null && optimizedThumbnailPath.isNotEmpty) ? optimizedThumbnailPath : thumbnailPath,
                      fit: fit,
                      cacheManager: KnockpostImageCacheManager.instance,
                      imageBuilder: (context, imageProvider) {
                        PerformanceService.instance.incrementGlimpsImageCacheHit();
                        return Image(image: imageProvider, fit: fit);
                      },
                      placeholder: (context, url) {
                        PerformanceService.instance.incrementGlimpsImageCacheMiss();
                        return Container(color: Colors.grey.shade900);
                      },
                      errorWidget: (_, __, ___) {
                        if (optimizedThumbnailPath != null && 
                            optimizedThumbnailPath.isNotEmpty && 
                            optimizedThumbnailPath != thumbnailPath) {
                          // Fallback to original unoptimized image if the optimized one fails
                          return CachedNetworkImage(
                            imageUrl: thumbnailPath,
                            fit: fit,
                            cacheManager: KnockpostImageCacheManager.instance,
                            imageBuilder: (context, imageProvider) {
                              PerformanceService.instance.incrementGlimpsImageCacheHit();
                              return Image(image: imageProvider, fit: fit);
                            },
                            placeholder: (context, url) {
                              PerformanceService.instance.incrementGlimpsImageCacheMiss();
                              return Container(color: Colors.grey.shade900);
                            },
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade900,
                              child: const Center(
                                child: Icon(Icons.error, color: Colors.white54),
                              ),
                            ),
                          );
                        }
                        return Container(
                          color: Colors.grey.shade900,
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.white54),
                          ),
                        );
                      },
                    );
                  } else if (thumbnailPath.isNotEmpty) {
                    return Image.file(File(thumbnailPath), fit: fit);
                  }
                  return Container(color: Colors.grey.shade900);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final screenW = constraints.maxWidth;
                    final screenH = constraints.maxHeight;

                    Widget buildForeground(Widget child) {
                      final transformMap = glimpse.mediaTransform;
                      if (transformMap != null) {
                        final double scale = transformMap['scale'] ?? 1.0;
                        final double translateX = transformMap['translateX'] ?? 0.0;
                        final double translateY = transformMap['translateY'] ?? 0.0;
                        final double rotation = transformMap['rotation'] ?? 0.0;
                        final double savedW = transformMap['containerWidth'] ?? screenW;
                        final double savedH = transformMap['containerHeight'] ?? screenH;

                        final scaleX = screenW / (savedW > 0 ? savedW : screenW);
                        final scaleY = screenH / (savedH > 0 ? savedH : screenH);

                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..translateByDouble(translateX * scaleX, translateY * scaleY, 0.0, 1.0)
                            ..scaleByDouble(scale, scale, scale, 1.0)
                            ..rotateZ(rotation),
                          child: child,
                        );
                      }
                      return child;
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45, tileMode: TileMode.clamp),
                          child: buildImage(BoxFit.cover),
                        ),
                        Container(color: Colors.black.withValues(alpha: 0.35)),
                        buildForeground(buildImage(BoxFit.cover)),
                      ],
                    );
                  },
                );
              }),

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
                        future: UserCacheService.instance.getUserProfile(
                          glimpse.authorId,
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final realUser = UserModel(
                            id: glimpse.authorId,
                            displayName: snapshot.data!['displayName'] ?? snapshot.data!['username'] ?? 'User',
                            username: snapshot.data!['username'] ?? glimpse.authorId,
                            avatarAsset: snapshot.data!['profileImageUrl'],
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
                  fontWeight: FontWeight.w700,
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

class _GlimpseVideoThumbnail extends StatefulWidget {
  final String path;

  const _GlimpseVideoThumbnail({required this.path});

  @override
  State<_GlimpseVideoThumbnail> createState() => _GlimpseVideoThumbnailState();
}

class _GlimpseVideoThumbnailState extends State<_GlimpseVideoThumbnail> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.path.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else if (widget.path.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(
        widget.path,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else {
      _controller = VideoPlayerController.file(
        File(widget.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }

    _controller
        .initialize()
        .then((_) {
          if (mounted) setState(() => _initialized = true);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.white54, size: 32),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

