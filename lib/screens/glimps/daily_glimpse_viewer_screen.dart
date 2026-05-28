import 'dart:async';
import 'package:knockpost/widgets/knockpost_refresh.dart';
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
import 'package:just_audio/just_audio.dart';
import 'package:colorfilter_generator/presets.dart';
import '../../utils/audio_lifecycle_manager.dart';
import '../shared/music_editor_screen.dart';
import '../../services/post_service.dart';
import 'package:intl/intl.dart';
import '../../models/daily_glimpse_card_model.dart';
import '../../services/daily_glimpse_service.dart';

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

/// Opens the Daily Glimpse viewer with a custom scale/fade page route.
void openDailyGlimpseViewer(
  BuildContext context, {
  required List<DailyGlimpseCard> dailyCards,
  required int initialCardIndex,
  required List<PostModel> allGlimpses,
  required UserModel user,
}) {
  Navigator.of(context).push(
    _DailyGlimpseViewerRoute(
      page: DailyGlimpseViewerScreen(
        dailyCards: dailyCards,
        initialCardIndex: initialCardIndex,
        allGlimpses: allGlimpses,
        user: user,
      ),
    ),
  );
}

// ── Custom Route with scale + fade transition ──────────────────────────────
class _DailyGlimpseViewerRoute extends PageRouteBuilder {
  _DailyGlimpseViewerRoute({required Widget page})
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

// ── DailyGlimpseViewerScreen (PageView wrapper) ─────────────────────────────────
class DailyGlimpseViewerScreen extends StatefulWidget {
  final List<DailyGlimpseCard> dailyCards;
  final int initialCardIndex;
  final List<PostModel> allGlimpses;
  final UserModel user;

  const DailyGlimpseViewerScreen({
    super.key,
    required this.dailyCards,
    required this.initialCardIndex,
    required this.allGlimpses,
    required this.user,
  });

  @override
  State<DailyGlimpseViewerScreen> createState() => _DailyGlimpseViewerScreenState();
}

class _DailyGlimpseViewerScreenState extends State<DailyGlimpseViewerScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialCardIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextCard() {
    if (_pageController.page!.toInt() < widget.dailyCards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPrevCard() {
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
        itemCount: widget.dailyCards.length,
        itemBuilder: (context, index) {
          final card = widget.dailyCards[index];
          final glimpses = DailyGlimpseService.instance.getGlimpsesForCard(card, widget.allGlimpses);
          
          return _SingleCardGlimpseViewer(
            key: ValueKey(card.id),
            glimpses: glimpses,
            card: card,
            user: widget.user,
            onFinished: _goToNextCard,
            onGoToPreviousCard: _goToPrevCard,
          );
        },
      ),
    );
  }
}

// ── SingleCardGlimpseViewer ────────────────────────────────────────────────
class _SingleCardGlimpseViewer extends StatefulWidget {
  final List<PostModel> glimpses;
  final DailyGlimpseCard card;
  final UserModel user;
  final VoidCallback onFinished;
  final VoidCallback onGoToPreviousCard;

  const _SingleCardGlimpseViewer({
    super.key,
    required this.glimpses,
    required this.card,
    required this.user,
    required this.onFinished,
    required this.onGoToPreviousCard,
  });

  @override
  State<_SingleCardGlimpseViewer> createState() => _SingleCardGlimpseViewerState();
}

class _SingleCardGlimpseViewerState extends State<_SingleCardGlimpseViewer>
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
  static const Color _accentColor = Colors.white;
  static const Color _accentGlow = Colors.white70;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_glimpseDuration * 1000).toInt()),
    )..addStatusListener(_onProgressComplete);

    _progressController.forward();

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _recordCurrentGlimpseView();
  }

  void _recordCurrentGlimpseView() {
    final glimpse = widget.glimpses[_currentIndex];
    PostService.instance.incrementViewCount(glimpse.id, glimpse.authorId);
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
      _recordCurrentGlimpseView();
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
      _recordCurrentGlimpseView();
      _progressController.reset();
      _progressController.forward();
    } else {
      // Already first — go to prev card!
      widget.onGoToPreviousCard();
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
    final glimpse = widget.glimpses[_currentIndex];
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
                          glimpse,
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

                      // ── Date Label (Daily Archive) ──
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 32,
                        left: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.white.withValues(alpha: 0.65),
                                    size: 9,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('d MMM yyyy').format(widget.card.date).toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                     postAuthor: widget.user,
                     isPostOwner: widget.user.isOwnProfile,
                     initialLikes: glimpse.likes,
                     initialViews: glimpse.views,
                     timestamp: glimpse.relativeTime,
                     showShare: false,
                     transparentButtons: true,
                     alignSummaryRight: true,
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
              user: _user,
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
                  colors: [_accentColor, _accentGlow, Colors.white30],
                ),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                  image: widget.user.avatarAsset != null
                      ? DecorationImage(
                          image: ImageHelper.resolveImage(widget.user.avatarAsset)!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.user.avatarAsset == null
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
                    widget.user.displayName,
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


  Widget _buildGlimpseImage(PostModel glimpse, {Key? key}) {
    return _GlimpseMediaItem(
      key: key,
      glimpse: glimpse,
      progressController: _progressController,
    );
  }
}

class _DisplayPainter extends CustomPainter {
  final List<Map<String, dynamic>> drawPaths;
  final Size screenSize;

  _DisplayPainter({required this.drawPaths, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final pathData in drawPaths) {
      final pointsData = pathData['points'] as List?;
      if (pointsData == null || pointsData.length < 2) continue;

      final colorValue = pathData['color'] as int?;
      final color = colorValue != null ? Color(colorValue) : Colors.white;
      final strokeWidth = (pathData['strokeWidth'] as num?)?.toDouble() ?? 5.0;

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final uiPath = Path();
      for (int i = 0; i < pointsData.length; i++) {
        final pt = pointsData[i] as Map;
        final x = (pt['x'] as num).toDouble() * screenSize.width;
        final y = (pt['y'] as num).toDouble() * screenSize.height;
        if (i == 0) {
          uiPath.moveTo(x, y);
        } else {
          uiPath.lineTo(x, y);
        }
      }
      canvas.drawPath(uiPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GlimpseMediaItem extends StatefulWidget {
  final PostModel glimpse;
  final AnimationController progressController;

  const _GlimpseMediaItem({
    super.key,
    required this.glimpse,
    required this.progressController,
  });

  @override
  State<_GlimpseMediaItem> createState() => _GlimpseMediaItemState();
}

class _GlimpseMediaItemState extends State<_GlimpseMediaItem> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;

  final List<Map<String, dynamic>> _carouselEffects = [
    {'id': 'none', 'label': 'Normal'},
    {'id': 'aesthetic', 'label': 'Paris'},
    {'id': 'suave', 'label': 'Oslo'},
    {'id': 'losangeles', 'label': 'L.A.'},
    {'id': 'bw', 'label': 'Classic'},
    {'id': 'zohan', 'label': 'Tokyo'},
    {'id': 'lowlight', 'label': 'Melbourne'},
    {'id': 'camcorder', 'label': 'VHS'},
    {'id': 'vivid', 'label': 'Jakarta'},
    {'id': 'vintage', 'label': 'Retro'},
    {'id': 'noir', 'label': 'Noir'},
    {'id': 'warm', 'label': 'Golden'},
    {'id': 'cool', 'label': 'Moody'},
    {'id': 'dream', 'label': 'Dream'},
    {'id': 'cinematic', 'label': 'Cinema'},
    {'id': 'fade', 'label': 'Lo-Fi'},
    {'id': 'dramatic', 'label': 'Dramatic'},
    {'id': 'sunset', 'label': 'Peach'},
  ];

  ColorFilter _getActiveColorFilter(int index) {
    if (index == 0) {
      return const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    final effectId = _carouselEffects[index]['id'];
    switch (effectId) {
      case 'aesthetic': return ColorFilter.matrix(PresetFilters.reyes.matrix);
      case 'suave': return ColorFilter.matrix(PresetFilters.slumber.matrix);
      case 'losangeles': return ColorFilter.matrix(PresetFilters.valencia.matrix);
      case 'bw': return ColorFilter.matrix(PresetFilters.willow.matrix);
      case 'zohan': return ColorFilter.matrix(PresetFilters.juno.matrix);
      case 'lowlight': return ColorFilter.matrix(PresetFilters.gingham.matrix);
      case 'camcorder': return ColorFilter.matrix(PresetFilters.stinson.matrix);
      case 'vivid': return ColorFilter.matrix(PresetFilters.clarendon.matrix);
      case 'vintage': return ColorFilter.matrix(PresetFilters.maven.matrix);
      case 'noir': return ColorFilter.matrix(PresetFilters.moon.matrix);
      case 'warm': return ColorFilter.matrix(PresetFilters.rise.matrix);
      case 'cool': return ColorFilter.matrix(PresetFilters.amaro.matrix);
      case 'dream': return ColorFilter.matrix(PresetFilters.ludwig.matrix);
      case 'cinematic': return ColorFilter.matrix(PresetFilters.xProII.matrix);
      case 'fade': return ColorFilter.matrix(PresetFilters.brooklyn.matrix);
      case 'dramatic': return ColorFilter.matrix(PresetFilters.mayfair.matrix);
      case 'sunset': return ColorFilter.matrix(PresetFilters.aden.matrix);
      default: return const ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  @override
  void initState() {
    super.initState();
    final path = widget.glimpse.imagePaths.isNotEmpty ? widget.glimpse.imagePaths.first : '';
    final pathLower = path.toLowerCase();
    final isVideo =
        pathLower.contains('.mp4') ||
        pathLower.contains('.mov') ||
        pathLower.contains('.mkv') ||
        pathLower.contains('.webm') ||
        pathLower.contains('.avi');

    if (isVideo) {
      if (path.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(path));
      } else if (path.startsWith('assets/')) {
        _videoController = VideoPlayerController.asset(path);
      } else {
        _videoController = VideoPlayerController.file(File(path));
      }

      widget.progressController.stop();

      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(false);
          _videoController!.setVolume(widget.glimpse.originalAudioVolume ?? 1.0);
          _videoController!.play();

          widget.progressController.duration = _videoController!.value.duration;
          widget.progressController.forward(from: 0);
        }
      });
    } else {
      widget.progressController.duration = const Duration(seconds: 6);
      widget.progressController.forward(from: 0);
    }

    if (widget.glimpse.musicUrl != null && widget.glimpse.musicUrl!.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      AudioLifecycleManager.instance.register(_audioPlayer!);
      _setupAudioPlayer();
    }
  }

  Future<void> _setupAudioPlayer() async {
    try {
      await _audioPlayer!.setUrl(widget.glimpse.musicUrl!);
      await _audioPlayer!.seek(Duration(seconds: widget.glimpse.musicTrimStart ?? 0));
      await _audioPlayer!.setVolume(widget.glimpse.musicVolume ?? 1.0);
      await _audioPlayer!.setLoopMode(LoopMode.one);
      await _audioPlayer!.play();
    } catch (e) {
      debugPrint("GlimpseAudioPlayer Error: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    if (_audioPlayer != null) {
      AudioLifecycleManager.instance.unregister(_audioPlayer!);
      _audioPlayer!.stop().whenComplete(() => _audioPlayer!.dispose());
    }
    super.dispose();
  }

  Widget _buildImageWidget(String path, BoxFit fit) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: fit);
    } else if (path.startsWith('http')) {
      return Image.network(path, fit: fit);
    } else if (path.isNotEmpty) {
      return Image.file(File(path), fit: fit);
    }
    return Container(color: Colors.black);
  }

  Widget _buildBaseMedia() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        Widget buildForeground(Widget child) {
          final transformMap = widget.glimpse.mediaTransform;
          if (transformMap != null) {
            final double scale = transformMap['scale'] ?? 1.0;
            final double translateX = transformMap['translateX'] ?? 0.0;
            final double translateY = transformMap['translateY'] ?? 0.0;
            final double rotation = transformMap['rotation'] ?? 0.0;
            final double savedW = transformMap['containerWidth'] ?? screenW;
            final double savedH = transformMap['containerHeight'] ?? screenH;

            // Normalize translation for current screen bounds
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

        final path = widget.glimpse.imagePaths.isNotEmpty ? widget.glimpse.imagePaths.first : '';
        if (_videoController != null) {
          final isInitialized = _videoController!.value.isInitialized;
          
          if (!isInitialized) return Container(color: Colors.black);

          final videoWidget = SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          );

          if (widget.glimpse.mediaTransform != null) {
            // Apply transform to video if transform exists
            return Stack(
              fit: StackFit.expand,
              children: [
                if (widget.glimpse.type == PostType.glimps) ...[
                   ImageFiltered(
                     imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45, tileMode: TileMode.decal),
                     child: videoWidget,
                   ),
                   Container(color: Colors.black.withValues(alpha: 0.35)),
                ],
                SizedBox.expand(
                  child: buildForeground(
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  )
                )
              ]
            );
          }
          return videoWidget;
        }

        if (path.isEmpty) return Container(color: Colors.black);

        final isGlimpse = widget.glimpse.type == PostType.glimps;
        if (isGlimpse || widget.glimpse.mediaTransform != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Blurred background (cover)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45, tileMode: TileMode.decal),
                child: SizedBox.expand(child: _buildImageWidget(path, BoxFit.cover)),
              ),
              Container(color: Colors.black.withValues(alpha: 0.35)),
              // Contained foreground (full image, no crop)
              SizedBox.expand(child: buildForeground(_buildImageWidget(path, BoxFit.contain))),
            ],
          );
        }

        return SizedBox.expand(child: _buildImageWidget(path, BoxFit.cover));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _buildBaseMedia();

    final filterIndex = widget.glimpse.filterIndex ?? 0;
    if (filterIndex > 0 && filterIndex < _carouselEffects.length) {
      content = ColorFiltered(
        colorFilter: _getActiveColorFilter(filterIndex),
        child: content,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            content,

            if (widget.glimpse.drawPaths != null && widget.glimpse.drawPaths!.isNotEmpty)
              CustomPaint(
                size: Size.infinite,
                painter: _DisplayPainter(
                  drawPaths: widget.glimpse.drawPaths!,
                  screenSize: size,
                ),
              ),

            if (widget.glimpse.textOverlays != null)
              ...widget.glimpse.textOverlays!.map((textData) {
                final text = textData['text'] as String? ?? '';
                final xNormalized = (textData['x'] as num?)?.toDouble() ?? 0.5;
                final yNormalized = (textData['y'] as num?)?.toDouble() ?? 0.5;
                final scale = (textData['scale'] as num?)?.toDouble() ?? 1.0;
                final colorValue = textData['color'] as int?;
                final color = colorValue != null ? Color(colorValue) : Colors.white;

                final x = xNormalized * size.width;
                final y = yNormalized * size.height;

                return Positioned(
                  left: x,
                  top: y,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 32 * scale,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                );
              }),

            if (widget.glimpse.musicStickerConfig != null &&
                (widget.glimpse.musicStickerConfig!['showSticker'] ?? true))
              RepaintBoundary(
                child: MusicStickerWidget(
                  title: widget.glimpse.musicTitle ?? '',
                  artist: widget.glimpse.musicArtist ?? '',
                  coverUrl: widget.glimpse.musicCoverUrl ?? '',
                  configData: widget.glimpse.musicStickerConfig,
                  isPlaying: true,
                  isEditable: false,
                ),
              ),
          ],
        );
      },
    );
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
