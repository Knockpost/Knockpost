import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/image_helper.dart';
import '../../widgets/reaction_bar.dart';
import '../../services/current_user_service.dart';
import '../../services/post_service.dart';
import '../profile/other_profile_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/more_options_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WavesFeedCard — Premium cinematic video card for Waves in Home Feed
//
// • Tall portrait layout with edge-to-edge video
// • Auto-play when visible, pause when scrolled away
// • Three-layer adaptive overlay system for universal readability
// • Cinematic bottom zone with creator info + actions
// • Instagram/Reels-style interactions:
//     Single tap  → toggle sound
//     Double tap  → like reaction
//     Long press  → pause video (release → resume)
// ─────────────────────────────────────────────────────────────────────────────

class WavesFeedCard extends StatefulWidget {
  final PostModel post;
  final UserModel user;
  /// Optional callback (kept for API compatibility)
  final VoidCallback? onTap;

  const WavesFeedCard({
    super.key,
    required this.post,
    required this.user,
    this.onTap,
  });

  @override
  State<WavesFeedCard> createState() => _WavesFeedCardState();
}

class _WavesFeedCardState extends State<WavesFeedCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isVisible = false;
  bool _isMuted = true;
  bool _doubleTapped = false;

  // ── Interaction state ───────────────────────────────────────────────────
  bool _showSoundIndicator = false;

  // ── Spacing & sizing constants ──────────────────────────────────────────
  static const double _overlayPaddingH = 16.0;
  static const double _overlayPaddingBottom = 16.0;
  static const double _avatarSize = 32.0;

  // ── Text shadow presets ─────────────────────────────────────────────────
  static const List<Shadow> _strongShadow = [
    Shadow(color: Color(0xDE000000), blurRadius: 6),
  ];
  static const List<Shadow> _mediumShadow = [
    Shadow(color: Color(0x8A000000), blurRadius: 4),
  ];
  static const List<Shadow> _lightShadow = [
    Shadow(color: Color(0x61000000), blurRadius: 3),
  ];

  // ── Icon shadow for bare icons on media ─────────────────────────────────
  static const List<Shadow> _iconShadow = [
    Shadow(color: Color(0xCC000000), blurRadius: 8),
  ];

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    final path = widget.post.imagePaths.isNotEmpty
        ? widget.post.imagePaths.first
        : '';
    if (path.isEmpty) return;

    if (path.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(path));
    } else if (path.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(path);
    } else {
      _controller = VideoPlayerController.file(File(path));
    }

    _controller!.initialize().then((_) {
      if (!mounted) return;
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Start muted
      setState(() => _initialized = true);
      if (_isVisible) {
        _controller!.play();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final wasVisible = _isVisible;
    _isVisible = info.visibleFraction > 0.6;

    if (_isVisible && !wasVisible) {
      _controller?.play();
    } else if (!_isVisible && wasVisible) {
      _controller?.pause();
    }
  }

  // ── Interaction: Single Tap → Toggle Sound ─────────────────────────────
  void _onTap() {
    KnockHaptics.tap();
    setState(() {
      _isMuted = !_isMuted;
      _showSoundIndicator = true;
    });
    _controller?.setVolume(_isMuted ? 0 : 1);

    // Brief indicator then fade
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showSoundIndicator = false);
    });
  }

  // ── Interaction: Double Tap → Like ─────────────────────────────────────
  void _onDoubleTap() {
    KnockHaptics.impact();
    setState(() => _doubleTapped = true);
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  // ── Interaction: Long Press → Pause / Release → Resume ─────────────────
  void _onLongPressStart(LongPressStartDetails details) {
    KnockHaptics.tap();
    _controller?.pause();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_isVisible) {
      _controller?.play();
    }
  }

  void _openProfile() {
    KnockHaptics.tap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          Widget buildScreen(List<PostModel> currentPosts) {
            if (widget.user.isOwnProfile) {
              return ProfileScreen(
                user: widget.user,
                posts: currentPosts,
              );
            } else {
              return OtherProfileScreen(
                user: widget.user,
                posts: currentPosts,
              );
            }
          }

          return StreamBuilder<List<PostModel>>(
            stream: PostService.instance.getUserPosts(widget.user.id),
            builder: (context, snapshot) {
              return buildScreen(snapshot.data ?? []);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Tall portrait card — 16:9 ratio in feed
    final cardHeight = screenWidth * (16 / 9);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VisibilityDetector(
      key: Key('wave_${widget.post.id}_$hashCode'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: screenWidth - 12,
            height: cardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Layer 1: Video / Thumbnail ──
                _buildVideoLayer(),

                // ── Layer 2: Adaptive gradient overlays ──
                _buildGradients(cardHeight),

                // ── Layer 3: Sound toggle indicator ──
                _buildSoundIndicator(),

                // ── Layer 4: Gesture handler (tap/double-tap/long-press) ──
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onTap,
                    onDoubleTap: _onDoubleTap,
                    onLongPressStart: _onLongPressStart,
                    onLongPressEnd: _onLongPressEnd,
                  ),
                ),

                // ── Layer 5: Top-right three-dot menu (bare icon) ──
                Positioned(
                  top: _overlayPaddingH,
                  right: _overlayPaddingH,
                  child: GestureDetector(
                    onTap: _openMoreOptions,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 22,
                        shadows: _iconShadow,
                      ),
                    ),
                  ),
                ),

                // ── Layer 6: Bottom cinematic overlay ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomOverlay(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Video Layer ──────────────────────────────────────────────────────────
  Widget _buildVideoLayer() {
    if (_initialized && _controller != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    // Fallback: thumbnail (only use coverImagePath, since imagePaths.first is a video)
    final path = widget.post.coverImagePath ?? '';
    if (path.isEmpty) {
      return Container(color: const Color(0xFF0A0A0A));
    }

    Widget image;
    if (path.startsWith('assets/')) {
      image = Image.asset(path, fit: BoxFit.cover);
    } else if (path.startsWith('http')) {
      image = Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: const Color(0xFF0A0A0A)),
      );
    } else {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: const Color(0xFF0A0A0A)),
      );
    }

    return SizedBox.expand(child: image);
  }

  // ── Three-Layer Adaptive Gradient System ─────────────────────────────────
  Widget _buildGradients(double cardHeight) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Top vignette — ensures control visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Layer 2: Cinematic bottom gradient — extends high for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: cardHeight * 0.45,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Layer 3: Subtle radial edge vignette — cinematic depth
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sound Toggle Indicator (brief center icon) ──────────────────────────
  Widget _buildSoundIndicator() {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _showSoundIndicator ? 1.0 : 0.0,
          duration: Duration(milliseconds: _showSoundIndicator ? 150 : 300),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  // ── More Options Handler ────────────────────────────────────────────────
  void _openMoreOptions() {
    KnockHaptics.tap();
    final currentUser = CurrentUserService.instance.currentUser;
    final isOwner =
        currentUser != null && widget.post.authorId == currentUser.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MoreOptionsSheet(
          userId: widget.user.id,
          username: widget.user.username,
          user: widget.user,
          postId: widget.post.id,
          isReel: true,
          isOwner: isOwner,
          postTypeName: 'Wave',
        );
      },
    );
  }

  // ── Bottom Cinematic Overlay ────────────────────────────────────────────
  Widget _buildBottomOverlay(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _overlayPaddingH,
        0,
        _overlayPaddingH,
        _overlayPaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Music chip
          if (widget.post.musicTitle != null &&
              widget.post.musicTitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMusicRow(),
            ),

          // Creator row — tap করলে profile খুলবে
          GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                // Avatar with subtle ring
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white70,
                        Colors.white54,
                        Colors.white38,
                      ],
                    ),
                  ),
                  child: Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                      image: widget.user.avatarAsset != null
                          ? DecorationImage(
                              image: ImageHelper.resolveImage(
                                  widget.user.avatarAsset)!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.user.avatarAsset == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 17,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                // Creator name
                Text(
                  widget.user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    shadows: _strongShadow,
                  ),
                ),
                if (widget.user.isOwnProfile) ...[
                  const SizedBox(width: 6),
                  // Timestamp — always readable with shadow
                  Text(
                    widget.post.relativeTime,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      shadows: _mediumShadow,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Caption (max 2 lines)
          if (widget.post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.post.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  shadows: _mediumShadow,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Reaction bar
          ReactionBar(
            doubleTapped: _doubleTapped,
            onDoubleTapHandled: _onDoubleTapHandled,
            postId: widget.post.id,
            isPostOwner: widget.user.isOwnProfile,
            initialLikes: widget.post.likes,
            initialViews: widget.post.views,
            postAuthor: widget.user,
            shareUsername: widget.user.username,
            shareCaption: widget.post.text,
            timestamp: widget.post.timestampText,
            transparentButtons: true,
          ),
        ],
      ),
    );
  }

  // ── Music Row ──────────────────────────────────────────────────────────
  Widget _buildMusicRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.7),
          size: 13,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${widget.post.musicTitle}${widget.post.musicArtist != null ? ' • ${widget.post.musicArtist}' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              shadows: _lightShadow,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
