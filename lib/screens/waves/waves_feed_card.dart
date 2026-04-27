import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/reaction_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WavesFeedCard — Premium video-first card for Waves content in Home Feed
//
// • Tall portrait layout with edge-to-edge video
// • Auto-play when visible, pause when scrolled away
// • Glassmorphic overlay UI (username, caption, music)
// • Tap → opens fullscreen Waves viewer
// • Unique Knockpost identity — NOT an Instagram copy
// ─────────────────────────────────────────────────────────────────────────────

class WavesFeedCard extends StatefulWidget {
  final PostModel post;
  final UserModel user;

  const WavesFeedCard({
    super.key,
    required this.post,
    required this.user,
  });

  @override
  State<WavesFeedCard> createState() => _WavesFeedCardState();
}

class _WavesFeedCardState extends State<WavesFeedCard>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isVisible = false;
  bool _isMuted = true;
  bool _showPlayIcon = false;
  bool _doubleTapped = false;

  late final AnimationController _pulseController;

  // Knockpost monochrome style
  static const Color _waveAccent = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
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
    _pulseController.dispose();
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

  void _toggleMute() {
    KnockHaptics.tap();
    setState(() => _isMuted = !_isMuted);
    _controller?.setVolume(_isMuted ? 0 : 1);
  }

  void _onTap() {
    KnockHaptics.tap();
    // Toggle play/pause with visual feedback
    if (_controller?.value.isPlaying == true) {
      _controller?.pause();
      setState(() => _showPlayIcon = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showPlayIcon = false);
      });
    } else {
      _controller?.play();
      setState(() => _showPlayIcon = false);
    }
  }

  void _onDoubleTap() {
    KnockHaptics.impact();
    setState(() => _doubleTapped = true);
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Tall portrait card — 2:3 ratio in feed
    final cardHeight = screenWidth * 1.5;
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
                // ── Video / Thumbnail Background ──
                _buildVideoLayer(),

                // ── Gradient overlays ──
                _buildGradients(),

                // ── Play/Pause indicator ──
                if (_showPlayIcon)
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),

                // ── "WAVES" badge — top left ──
                Positioned(
                  top: 14,
                  left: 14,
                  child: _buildWavesBadge(),
                ),

                // ── Mute toggle — top right ──
                Positioned(
                  top: 14,
                  right: 14,
                  child: _buildMuteButton(),
                ),

                // ── Bottom overlay: user + caption + reactions ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomOverlay(isDark),
                ),

                // ── Tap handler (full card) ──
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onTap,
                    onDoubleTap: _onDoubleTap,
                  ),
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

    // Fallback: thumbnail
    final path = widget.post.coverImagePath ??
        (widget.post.imagePaths.isNotEmpty ? widget.post.imagePaths.first : '');
    if (path.isEmpty) {
      return Container(color: const Color(0xFF0A0A0A));
    }

    Widget image;
    if (path.startsWith('assets/')) {
      image = Image.asset(path, fit: BoxFit.cover);
    } else if (path.startsWith('http')) {
      image = Image.network(path, fit: BoxFit.cover);
    } else {
      image = Image.file(File(path), fit: BoxFit.cover);
    }

    return SizedBox.expand(child: image);
  }

  // ── Gradient Overlays ──────────────────────────────────────────────────
  Widget _buildGradients() {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom gradient — stronger for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Waves Badge ────────────────────────────────────────────────────────
  Widget _buildWavesBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _waveAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _waveAccent.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Icon(
                    Icons.play_circle_filled_rounded,
                    color: _waveAccent.withValues(
                      alpha: 0.7 + _pulseController.value * 0.3,
                    ),
                    size: 14,
                  );
                },
              ),
              const SizedBox(width: 5),
              const Text(
                'Wave',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mute Button ────────────────────────────────────────────────────────
  Widget _buildMuteButton() {
    return GestureDetector(
      onTap: _toggleMute,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Overlay ─────────────────────────────────────────────────────
  Widget _buildBottomOverlay(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Music chip
          if (widget.post.musicTitle != null &&
              widget.post.musicTitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMusicRow(),
            ),

          // User row
          Row(
            children: [
              // Avatar with wave ring
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.white70, Colors.white54, Colors.white38],
                  ),
                ),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                    image: widget.user.avatarAsset != null
                        ? DecorationImage(
                            image: AssetImage(widget.user.avatarAsset!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.user.avatarAsset == null
                      ? const Icon(Icons.person, color: Colors.white54, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.user.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.post.relativeTime,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Caption (max 2 lines)
          if (widget.post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.post.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
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
          color: _waveAccent.withValues(alpha: 0.8),
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
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
