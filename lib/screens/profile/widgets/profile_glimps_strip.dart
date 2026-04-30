import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../../../models/user_model.dart';
import '../../../utils/haptic_helper.dart';
import '../../../widgets/staggered_entry_animation.dart';
import '../../../utils/image_helper.dart';
import '../../glimps/glimpse_viewer_screen.dart';

class ProfileGlimpsStrip extends StatelessWidget {
  final List<PostModel> glimpses;
  final UserModel user;

  const ProfileGlimpsStrip({
    super.key,
    required this.glimpses,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (glimpses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: SizedBox(
        height: 220, // Substantially larger height
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(), // Allows overscroll to pass to TabBarView!
          itemCount: glimpses.length,
          itemBuilder: (context, index) {
            final glimpse = glimpses[index];
            return StaggeredEntryAnimation(
              index: index,
              delay: const Duration(milliseconds: 40),
              // Default vertical offset matches the rest of the app cascade
              child: ProfileGlimpsCard(
                glimpse: glimpse,
                user: user,
                allGlimpses: glimpses,
                glimpseIndex: index,
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProfileGlimpsCard extends StatelessWidget {
  final PostModel glimpse;
  final UserModel user;
  final List<PostModel> allGlimpses;
  final int glimpseIndex;

  const ProfileGlimpsCard({
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
    
    // For video posts or glimpses that have a cover, prefer the cover image
    String thumbnailPath = glimpse.coverImagePath ?? '';
    if (thumbnailPath.isEmpty) {
      thumbnailPath = glimpse.imagePaths.first;
    }

    final hasVideoExtension = thumbnailPath.toLowerCase().endsWith('.mp4') ||
        thumbnailPath.toLowerCase().endsWith('.mov') ||
        thumbnailPath.toLowerCase().endsWith('.mkv');

    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        final allG = allGlimpses.isNotEmpty ? allGlimpses : [glimpse];
        openGlimpseViewer(
          context,
          glimpses: allG,
          user: user,
          initialIndex: glimpseIndex,
          heroTag: 'profile_glimpse_${glimpse.id}',
        );
      },
      child: Container(
        width: 145, // Substantially larger width
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Thumbnail
              Builder(
                builder: (context) {
                  if (hasVideoExtension) {
                    return _GlimpseVideoThumbnail(path: thumbnailPath);
                  }
                  final provider = ImageHelper.resolveImage(thumbnailPath);
                  return provider != null
                      ? Image(image: provider, fit: BoxFit.cover)
                      : const Icon(Icons.error, size: 24);
                },
              ),
            ],
          ),
        ),
      ),
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
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.path));
    } else if (widget.path.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(widget.path);
    } else {
      _controller = VideoPlayerController.file(File(widget.path));
    }

    _controller
        .initialize()
        .then((_) {
          if (mounted) setState(() => _initialized = true);
        })
        .catchError((_) {
          // Ignored for thumbnail
        });
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
        color: Colors.black12,
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
