import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/reaction_bar.dart';
import '../../services/current_user_service.dart';
import '../../utils/image_helper.dart';
import '../waves/widgets/more_options_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GlimpseViewerScreen — Premium full-screen story viewer
//
// • Story-style segmented progress bars
// • Tap-left / tap-right navigation
// • Vertical swipe-down to dismiss with parallax
// • Fluid scale+fade route transition from card
// • Unique Knockpost accent styling
// ─────────────────────────────────────────────────────────────────────────────

import '../../../services/database_service.dart';

/// Opens the Glimpse viewer with a custom scale/fade page route.
void openGlimpseViewer(
  BuildContext context, {
  required Map<String, List<PostModel>> groupedGlimpses,
  required List<String> authorIds,
  required int initialAuthorIndex,
  int initialGlimpseIndex = 0,
  String? heroTag,
}) {
  Navigator.of(context).push(
    _GlimpseViewerRoute(
      page: GlimpseViewerScreen(
        groupedGlimpses: groupedGlimpses,
        authorIds: authorIds,
        initialAuthorIndex: initialAuthorIndex,
        initialGlimpseIndex: initialGlimpseIndex,
        heroTag: heroTag,
      ),
    ),
  );
}

// ── Custom Route with scale + fade transition ──────────────────────────────
class _GlimpseViewerRoute extends PageRouteBuilder {
  _GlimpseViewerRoute({required Widget page})
    : super(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      );
}

// ── GlimpseViewerScreen (PageView wrapper) ─────────────────────────────────
class GlimpseViewerScreen extends StatefulWidget {
  final Map<String, List<PostModel>> groupedGlimpses;
  final List<String> authorIds;
  final int initialAuthorIndex;
  final int initialGlimpseIndex;
  final String? heroTag;

  const GlimpseViewerScreen({
    super.key,
    required this.groupedGlimpses,
    required this.authorIds,
    required this.initialAuthorIndex,
    this.initialGlimpseIndex = 0,
    this.heroTag,
  });

  @override
  State<GlimpseViewerScreen> createState() => _GlimpseViewerScreenState();
}

class _GlimpseViewerScreenState extends State<GlimpseViewerScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialAuthorIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextUser() {
    if (_pageController.page!.toInt() < widget.authorIds.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPrevUser() {
    if (_pageController.page!.toInt() > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.authorIds.length,
        itemBuilder: (context, index) {
          final authorId = widget.authorIds[index];
          final glimpses = widget.groupedGlimpses[authorId]!;
          final isInitialAuthor = index == widget.initialAuthorIndex;
          return _SingleUserGlimpseViewer(
            key: ValueKey(authorId),
            glimpses: glimpses,
            authorId: authorId,
            initialIndex: isInitialAuthor ? widget.initialGlimpseIndex : 0,
            onFinished: _goToNextUser,
            onGoToPreviousUser: _goToPrevUser,
          );
        },
      ),
    );
  }
}

// ── SingleUserGlimpseViewer ────────────────────────────────────────────────
class _SingleUserGlimpseViewer extends StatefulWidget {
  final List<PostModel> glimpses;
  final String authorId;
  final int initialIndex;
  final VoidCallback onFinished;
  final VoidCallback onGoToPreviousUser;

  const _SingleUserGlimpseViewer({
    super.key,
    required this.glimpses,
    required this.authorId,
    this.initialIndex = 0,
    required this.onFinished,
    required this.onGoToPreviousUser,
  });

  @override
  State<_SingleUserGlimpseViewer> createState() => _SingleUserGlimpseViewerState();
}

class _SingleUserGlimpseViewerState extends State<_SingleUserGlimpseViewer>
    with TickerProviderStateMixin {
  late int _currentIndex;
  UserModel? _user;
  late AnimationController _progressController;

  // Swipe-down dismiss state
  double _dragOffsetY = 0;
  double _dragScale = 1.0;
  bool _isDragging = false;

  // Per-glimpse duration (seconds)
  static const double _glimpseDuration = 6.0;

  // Knockpost accent
  static const Color _accentColor = Color(0xFF6C63FF);
  static const Color _accentGlow = Color(0xFF8B83FF);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.glimpses.length - 1);

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_glimpseDuration * 1000).toInt()),
    )..addStatusListener(_onProgressComplete);

    _progressController.forward();

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadUser();
  }

  Future<void> _loadUser() async {
    final cu = CurrentUserService.instance.currentUser;
    if (cu != null && cu.id == widget.authorId) {
      if (mounted) setState(() => _user = cu);
      return;
    }
    final data = await DatabaseService.instance.getUserProfile(widget.authorId, useCache: true);
    if (data != null && mounted) {
      setState(() {
        _user = UserModel.fromMap(data, widget.authorId);
      });
    }
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressComplete);
    _progressController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToNext();
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.glimpses.length - 1) {
      setState(() => _currentIndex++);
      _progressController.reset();
      _progressController.forward();
    } else {
      // Last glimpse — go to next user!
      widget.onFinished();
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressController.reset();
      _progressController.forward();
    } else {
      // Already first — go to prev user!
      widget.onGoToPreviousUser();
    }
  }

  void _onTapDown(TapDownDetails details) {
    // Pause progress while holding
    _progressController.stop();
  }

  void _onTapUp(TapUpDetails details) {
    KnockHaptics.tap();
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth * 0.35) {
      _goToPrevious();
    } else {
      _goToNext();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _progressController.stop();
    KnockHaptics.tap();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _progressController.forward();
  }

  // ── Swipe-down dismiss ──────────────────────────────────────────────────
  void _onVerticalDragStart(DragStartDetails _) {
    _isDragging = true;
    _progressController.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(0, 400);
      _dragScale = (1.0 - (_dragOffsetY / 800)).clamp(0.7, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffsetY > 120 || velocity > 600) {
      // Dismiss
      Navigator.of(context).pop();
    } else {
      // Snap back
      setState(() {
        _dragOffsetY = 0;
        _dragScale = 1.0;
      });
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _accentColor)),
      );
    }
    final glimpse = widget.glimpses[_currentIndex];
    final thumbnailPath = glimpse.imagePaths.isNotEmpty
        ? glimpse.imagePaths.first
        : '';
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final dismissOpacity = (1.0 - (_dragOffsetY / 300)).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedContainer(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(_dragScale, _dragScale, 1.0)
            ..setTranslationRaw(0.0, _dragOffsetY, 0.0),
          child: Opacity(
            opacity: dismissOpacity,
            // Outer Stack: gesture detector নিচে, action buttons উপরে
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-screen tap/swipe handler ──
                GestureDetector(
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onLongPressStart: _onLongPressStart,
                  onLongPressEnd: _onLongPressEnd,
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Background Image ──
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _buildGlimpseImage(
                          thumbnailPath,
                          key: ValueKey('glimpse_$_currentIndex'),
                        ),
                      ),

                      // ── Top gradient ──
                      Positioned(
                        top: 0, left: 0, right: 0, height: 140,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Bottom gradient ──
                      Positioned(
                        bottom: 0, left: 0, right: 0, height: 260,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.black.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // ── Progress Bars ──
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        left: 12, right: 12,
                        child: _buildProgressBars(),
                      ),

                      // ── Top Right Buttons ──
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 32,
                        right: 16,
                        child: Row(
                          children: [
                            _buildMoreOptionsButton(),
                            const SizedBox(width: 12),
                            _buildCloseButton(),
                          ],
                        ),
                      ),

                      // ── User info (bottom) ──
                      Positioned(
                        bottom: bottomPad + 76, // ReactionBar-এর উপরে
                        left: 20,
                        right: 20,
                        child: _buildUserOverlay(glimpse),
                      ),
                    ],
                  ),
                ),

                 // ── ReactionBar (Like + Comment) — GestureDetector-এর উপরে ──
                 // Post section-এর মতো same buttons, same like count
                 Positioned(
                   bottom: bottomPad + 16,
                   left: 16,
                   right: 16,
                   child: ReactionBar(
                     key: ValueKey('reaction_$_currentIndex'),
                     postId: glimpse.id,
                     postAuthor: _user!,
                     isPostOwner: _user!.isOwnProfile,
                     initialLikes: glimpse.likes,
                     initialViews: glimpse.views,
                     timestamp: glimpse.relativeTime,
                     showShare: false,
                   ),
                 ),
               ],
             ),
          ),
        ),
      ),
    );
  }


  // ── Progress Bars ──────────────────────────────────────────────────────
  Widget _buildProgressBars() {
    return Row(
      children: List.generate(widget.glimpses.length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 2.5,
              right: index == widget.glimpses.length - 1 ? 0 : 2.5,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(height: 3, child: _buildSingleBar(index)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSingleBar(int index) {
    if (index < _currentIndex) {
      // Completed — full accent
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          gradient: const LinearGradient(colors: [_accentColor, _accentGlow]),
        ),
      );
    } else if (index == _currentIndex) {
      // Active — animating
      return AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Stack(
            children: [
              // Background track
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Filled portion with gradient
              FractionallySizedBox(
                widthFactor: _progressController.value,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [_accentColor, _accentGlow],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      // Upcoming — dim track
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
  }

  // ── Close Button ──────────────────────────────────────────────────────
  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        Navigator.of(context).pop();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  // ── More Options Button ────────────────────────────────────────────────
  Widget _buildMoreOptionsButton() {
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        _progressController.stop();
        
        final glimpse = widget.glimpses[_currentIndex];
        final currentUser = CurrentUserService.instance.currentUser;
        final isOwner = currentUser != null && glimpse.authorId == currentUser.id;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return MoreOptionsSheet(
              userId: glimpse.authorId,
              username: isOwner ? currentUser.username : '',
              postId: glimpse.id,
              isReel: false,
              isOwner: isOwner,
              postTypeName: 'Glimpse',
            );
          },
        ).then((_) {
          if (mounted) _progressController.forward();
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  // ── User Info Overlay ──────────────────────────────────────────────────
  Widget _buildUserOverlay(PostModel glimpse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Music info (if any)
        if (glimpse.musicTitle != null && glimpse.musicTitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildMusicChip(glimpse),
          ),

        // User row
        Row(
          children: [
            // Avatar with accent ring
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accentColor, _accentGlow, Color(0xFFFF6B9D)],
                ),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                  image: _user!.avatarAsset != null
                      ? DecorationImage(
                          image: ImageHelper.resolveImage(_user!.avatarAsset)!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _user!.avatarAsset == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // Name + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user!.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    glimpse.relativeTime,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Music Chip ──────────────────────────────────────────────────────
  Widget _buildMusicChip(PostModel glimpse) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated music icon
              const _PulsingMusicIcon(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${glimpse.musicTitle}${glimpse.musicArtist != null ? ' • ${glimpse.musicArtist}' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlimpseImage(String path, {Key? key}) {
    return _GlimpseMediaItem(
      key: key,
      path: path,
      progressController: _progressController,
    );
  }
}

class _GlimpseMediaItem extends StatefulWidget {
  final String path;
  final AnimationController progressController;

  const _GlimpseMediaItem({
    super.key,
    required this.path,
    required this.progressController,
  });

  @override
  State<_GlimpseMediaItem> createState() => _GlimpseMediaItemState();
}

class _GlimpseMediaItemState extends State<_GlimpseMediaItem> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    final pathLower = widget.path.toLowerCase();
    final isVideo =
        pathLower.contains('.mp4') ||
        pathLower.contains('.mov') ||
        pathLower.contains('.mkv') ||
        pathLower.contains('.webm') ||
        pathLower.contains('.avi');

    if (isVideo) {
      if (widget.path.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.path),
        );
      } else if (widget.path.startsWith('assets/')) {
        _videoController = VideoPlayerController.asset(widget.path);
      } else {
        _videoController = VideoPlayerController.file(File(widget.path));
      }

      // Pause progress while loading
      widget.progressController.stop();

      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(false);
          _videoController!.setVolume(1.0);
          _videoController!.play();

          widget.progressController.duration = _videoController!.value.duration;
          widget.progressController.forward(from: 0);
        }
      });
    } else {
      // It's an image, reset duration to 6 seconds
      widget.progressController.duration = const Duration(seconds: 6);
      widget.progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoController != null) {
      return _videoController!.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          : Container(color: Colors.black);
    }

    Widget image;
    if (widget.path.startsWith('assets/')) {
      image = Image.asset(widget.path, fit: BoxFit.cover);
    } else if (widget.path.startsWith('http')) {
      image = Image.network(widget.path, fit: BoxFit.cover);
    } else if (widget.path.isNotEmpty) {
      image = Image.file(File(widget.path), fit: BoxFit.cover);
    } else {
      return Container(color: Colors.black);
    }

    return SizedBox.expand(child: image);
  }
}

// ── Pulsing Music Note Icon ──────────────────────────────────────────────
class _PulsingMusicIcon extends StatefulWidget {
  const _PulsingMusicIcon();

  @override
  State<_PulsingMusicIcon> createState() => _PulsingMusicIconState();
}

class _PulsingMusicIconState extends State<_PulsingMusicIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.85 + (_controller.value * 0.2),
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white.withValues(
              alpha: 0.7 + _controller.value * 0.3,
            ),
            size: 14,
          ),
        );
      },
    );
  }
}

// ── Glassmorphic action button for Glimpse viewer ────────────────────────────
class _GlimpseActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _GlimpseActionButton({required this.onTap, required this.child});

  @override
  State<_GlimpseActionButton> createState() => _GlimpseActionButtonState();
}

class _GlimpseActionButtonState extends State<_GlimpseActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _bounce.reset();
        _bounce.forward();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.6,
                ),
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
