import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../../../../models/daily_glimpse_card_model.dart';
import '../../../../models/post_model.dart';
import '../../../../models/user_model.dart';
import '../../../../utils/haptic_helper.dart';
import '../../../../utils/image_helper.dart';
import '../../glimps/daily_glimpse_viewer_screen.dart';
import '../../../../services/daily_glimpse_service.dart';

class DailyGlimpseCardWidget extends StatelessWidget {
  final DailyGlimpseCard card;
  final UserModel user;
  final List<PostModel> allUserGlimpses;
  final List<DailyGlimpseCard> allDailyCards;
  final int cardIndex;

  const DailyGlimpseCardWidget({
    super.key,
    required this.card,
    required this.user,
    required this.allUserGlimpses,
    required this.allDailyCards,
    required this.cardIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Find the newest glimpse in this card to use as cover
    final glimpses = DailyGlimpseService.instance.getGlimpsesForCard(card, allUserGlimpses);
    if (glimpses.isEmpty) return const SizedBox.shrink();
    
    final coverGlimpse = glimpses.last; // sorted ascending by createdAt, last is newest
    
    String thumbnailPath = coverGlimpse.coverImagePath ?? '';
    if (thumbnailPath.isEmpty && coverGlimpse.imagePaths.isNotEmpty) {
      thumbnailPath = coverGlimpse.imagePaths.first;
    }

    final hasVideoExtension = thumbnailPath.toLowerCase().endsWith('.mp4') ||
        thumbnailPath.toLowerCase().endsWith('.mov') ||
        thumbnailPath.toLowerCase().endsWith('.mkv');

    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        openDailyGlimpseViewer(
          context,
          dailyCards: allDailyCards,
          initialCardIndex: cardIndex,
          allGlimpses: allUserGlimpses,
          user: user,
        );
      },
      child: Container(
        width: 145, 
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
          child: Builder(
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
