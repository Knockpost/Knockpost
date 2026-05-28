import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/user_model.dart';
import '../utils/haptic_helper.dart';
import 'comment_sheet.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/waves/widgets/share_sheet.dart';
import 'reactors_sheet.dart';
import 'post_analytics_sheet.dart';
import '../services/like_service.dart';
import '../services/current_user_service.dart';
import 'dart:async';

/// Emoji data for the reaction popup
class ReactionEmoji {
  final String emoji;
  final String label;

  const ReactionEmoji(this.emoji, this.label);
}

const List<ReactionEmoji> _reactions = [
  ReactionEmoji('😢', 'Sad'),
  ReactionEmoji('🥰', 'Care'),
  ReactionEmoji('😂', 'Haha'),
  ReactionEmoji('👍', 'Like'),
  ReactionEmoji('❤', 'Love'),
  ReactionEmoji('🔥', 'Fire'),
];

class ReactionBar extends StatefulWidget {
  /// Triggered from PostCard double-tap
  final bool doubleTapped;
  final VoidCallback? onDoubleTapHandled;
  final String postId;
  final bool isPostOwner;
  final int initialLikes;
  final int initialViews;
  final UserModel postAuthor;
  final String? shareUsername;
  final String? shareCaption;
  final String? timestamp;

  /// false হলে Share button দেখায়েবে না (Glimpse-এ ব্যবহার হয়)
  final bool showShare;

  /// true হলে button-এর background transparent হবে, icon color adaptive
  /// (dark bg → white, light bg → black). Waves overlay-তে ব্যবহার হয়।
  final bool transparentButtons;

  const ReactionBar({
    super.key,
    this.doubleTapped = false,
    this.onDoubleTapHandled,
    this.postId = 'demo_post',
    this.isPostOwner = false,
    this.initialLikes = 0,
    this.initialViews = 0,
    required this.postAuthor,
    this.shareUsername,
    this.shareCaption,
    this.timestamp,
    this.showShare = true,
    this.transparentButtons = false,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar>
    with TickerProviderStateMixin {
  String? _selectedEmoji;
  StreamSubscription<String?>? _likeSub;

  // ── Popup state ──
  bool _showPopup = false;
  int _hoveredIndex = -1;
  late int _likesCount;
  final List<GlobalKey> _emojiKeys = List.generate(
    _reactions.length,
    (_) => GlobalKey(),
  );

  // ── Animations ──
  late AnimationController _popupController;
  late Animation<double> _popupScale;

  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.initialLikes;

    final currentUser = CurrentUserService.instance.currentUser;
    if (currentUser != null && widget.postId != 'demo_post') {
      _likeSub = LikeService.instance
          .userReaction(widget.postId, currentUser.id)
          .listen((reaction) {
            if (mounted) {
              setState(() {
                _selectedEmoji = reaction;
              });
            }
          });
    }

    // Popup open/close animation
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _popupScale = CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Heart / emoji bounce animation on select
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.95), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
        ]).animate(
          CurvedAnimation(
            parent: _heartController,
            curve: Curves.easeInOutCubic,
          ),
        );
  }

  @override
  void didUpdateWidget(covariant ReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.doubleTapped && !oldWidget.doubleTapped) {
      if (_selectedEmoji == null) {
        _selectWithAnimation('❤');
        setState(() => _likesCount++);

        final currentUser = CurrentUserService.instance.currentUser;
        if (currentUser != null && widget.postId != 'demo_post') {
          LikeService.instance.toggleLike(
            postId: widget.postId,
            userId: currentUser.id,
            postAuthorId: widget.postAuthor.id,
            isLiking: true,
          );
        }
      }
      if (widget.onDoubleTapHandled != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onDoubleTapHandled!();
        });
      }
    }
  }

  @override
  void dispose() {
    _likeSub?.cancel();
    _popupController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  /// Tap on reaction button → toggle ❤️
  void _onTapReaction() {
    KnockHaptics.tap();
    final isLiking = _selectedEmoji == null;

    if (isLiking) {
      _selectWithAnimation('❤');
      setState(() => _likesCount++);
    } else {
      // Already reacted → un-react
      setState(() {
        _selectedEmoji = null;
        _likesCount--;
      });
    }

    final currentUser = CurrentUserService.instance.currentUser;
    if (currentUser != null && widget.postId != 'demo_post') {
      LikeService.instance.toggleLike(
        postId: widget.postId,
        userId: currentUser.id,
        postAuthorId: widget.postAuthor.id,
        isLiking: isLiking,
        reactionType: _selectedEmoji ?? '❤',
      );
    }
  }

  /// Select emoji with bounce animation
  void _selectWithAnimation(String emoji) {
    KnockHaptics.impact();
    setState(() => _selectedEmoji = emoji);
    _heartController.forward(from: 0);
  }

  /// Build the right widget for each reaction
  /// Love & Like = flat solid Icons, everything else = emoji Text
  Widget _buildEmojiWidget(int index, double size) {
    final label = _reactions[index].label;
    if (label == 'Love') {
      return Icon(
        Icons.favorite,
        color: const Color(0xFFED4956),
        size: size + 4,
      );
    }
    return Text(_reactions[index].emoji, style: TextStyle(fontSize: size));
  }

  /// Build selected emoji for the reaction button
  Widget _buildSelectedWidget(String emoji, double size) {
    if (emoji == '❤') {
      return Icon(
        Icons.favorite,
        color: const Color(0xFFED4956),
        size: size + 2,
      );
    }
    return Text(emoji, style: TextStyle(fontSize: size));
  }

  // ── Long press drag logic (Facebook-style) ──

  void _onLongPressStart(LongPressStartDetails details) {
    KnockHaptics.vibrate();
    setState(() {
      _showPopup = true;
      _hoveredIndex = -1;
    });
    _popupController.forward(from: 0);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    // Find which emoji the finger is over
    for (int i = 0; i < _reactions.length; i++) {
      final key = _emojiKeys[i];
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;
      final pos = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final fingerPos = details.globalPosition;

      if (fingerPos.dx >= pos.dx &&
          fingerPos.dx <= pos.dx + size.width &&
          fingerPos.dy >= pos.dy - 40 &&
          fingerPos.dy <= pos.dy + size.height + 40) {
        if (_hoveredIndex != i) {
          KnockHaptics.vibrate();
          setState(() => _hoveredIndex = i);
        }
        return;
      }
    }
    // Finger not on any emoji
    if (_hoveredIndex != -1) {
      setState(() => _hoveredIndex = -1);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_hoveredIndex >= 0 && _hoveredIndex < _reactions.length) {
      final hadReaction = _selectedEmoji != null;
      _selectWithAnimation(_reactions[_hoveredIndex].emoji);
      if (!hadReaction) {
        setState(() => _likesCount++);
      }

      final currentUser = CurrentUserService.instance.currentUser;
      if (currentUser != null && widget.postId != 'demo_post') {
        LikeService.instance.toggleLike(
          postId: widget.postId,
          userId: currentUser.id,
          postAuthorId: widget.postAuthor.id,
          isLiking: true,
          reactionType: _reactions[_hoveredIndex].emoji,
        );
      }
    }
    setState(() {
      _showPopup = false;
      _hoveredIndex = -1;
    });
    _popupController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverlay = widget.transparentButtons;
    final bgColor = isOverlay
        ? const Color(0x40000000) // black @ 0.25 — subtle dark translucent
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2));
    final iconColor = isOverlay
        ? Colors.white.withValues(alpha: 0.95)
        : (isDark
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.black.withValues(alpha: 0.75));
    const buttonRadius = 12.0;
    const buttonSize = 40.0;
    const iconSize = 20.0;
    final buttonShadow = isOverlay
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
        : <BoxShadow>[];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main reaction bar row ──
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Left: Timestamp and Reaction Summary ──
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.timestamp != null && !widget.isPostOwner)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        widget.timestamp!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isOverlay
                              ? Colors.white.withValues(alpha: 0.6)
                              : (isDark ? Colors.white54 : Colors.black54),
                          shadows: isOverlay
                              ? const [
                                  Shadow(
                                    color: Color(0x8A000000),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  if (widget.isPostOwner)
                    _ReactionSummary(
                      likes: _likesCount,
                      views: widget.initialViews,
                      postId: widget.postId,
                      isDark: isDark,
                      userReaction: _selectedEmoji,
                      isOverlay: isOverlay,
                    ),
                ],
              ),

              // ── Right: Action Buttons ──
              Row(
                children: [
                  // Reaction button
                  RawGestureDetector(
                    gestures: {
                      LongPressGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            LongPressGestureRecognizer
                          >(
                            () => LongPressGestureRecognizer(
                              duration: const Duration(milliseconds: 150),
                            ),
                            (LongPressGestureRecognizer instance) {
                              instance
                                ..onLongPressStart = _onLongPressStart
                                ..onLongPressMoveUpdate = _onLongPressMoveUpdate
                                ..onLongPressEnd = _onLongPressEnd;
                            },
                          ),
                      TapGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            TapGestureRecognizer
                          >(() => TapGestureRecognizer(), (
                            TapGestureRecognizer instance,
                          ) {
                            instance.onTap = _onTapReaction;
                          }),
                    },
                    child: Container(
                      height: buttonSize,
                      width: buttonSize,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(buttonRadius),
                        boxShadow: buttonShadow,
                      ),
                      child: Center(
                        child: _selectedEmoji != null
                            ? ScaleTransition(
                                scale: _heartScale,
                                child: _buildSelectedWidget(
                                  _selectedEmoji!,
                                  28,
                                ),
                              )
                            : Image.asset(
                                // Always use dark variant on video overlay
                                (isDark || isOverlay)
                                    ? "assets/reaction_default_dark.png"
                                    : "assets/reaction_default_light.png",
                                width: 24,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 11),

                  // Comment button
                  GestureDetector(
                    onTap: () {
                      CommentSheet.show(
                        context,
                        postId: widget.postId,
                        postAuthor: widget.postAuthor,
                        isPostOwner: widget.isPostOwner,
                      );
                    },
                    child: Container(
                      height: buttonSize,
                      width: buttonSize,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(buttonRadius),
                        boxShadow: buttonShadow,
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(iconSize, iconSize),
                          painter: _ReplyIconPainter(color: iconColor),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 11),

                  // Share button
                  if (widget.showShare)
                    GestureDetector(
                      onTap: () {
                        KnockHaptics.tap();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ShareSheet(
                            url: 'https://knockpost.app/post/${widget.postId}',
                            username: widget.shareUsername ?? 'someone',
                            caption: widget.shareCaption ?? '',
                            contentType: 'post',
                          ),
                        );
                      },
                      child: Container(
                        height: buttonSize,
                        width: buttonSize,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(buttonRadius),
                          boxShadow: buttonShadow,
                        ),
                        child: Icon(
                          Icons.share_outlined,
                          size: iconSize,
                          color: iconColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Floating emoji popup (above button) ──
        if (_showPopup)
          Positioned(
            bottom: 52,
            right: -8,
            child: ScaleTransition(
              scale: _popupScale,
              alignment: Alignment.bottomRight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // ── White pill background (FIXED — never moves) ──
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_reactions.length, (_) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: SizedBox(width: 30, height: 30),
                        );
                      }),
                    ),
                  ),

                  // ── Emojis layer (float freely, no clip) ──
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_reactions.length, (index) {
                          final isHovered = _hoveredIndex == index;
                          final double staggerStart = index * 0.1;
                          final double staggerEnd = (staggerStart + 0.6).clamp(
                            0.0,
                            1.0,
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0, 0.5),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _popupController,
                                      curve: Interval(
                                        staggerStart,
                                        staggerEnd,
                                        curve: Curves.easeOutBack,
                                      ),
                                    ),
                                  ),
                              child: ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: _popupController,
                                  curve: Interval(
                                    staggerStart,
                                    staggerEnd,
                                    curve: Curves.easeOutBack,
                                  ),
                                ),
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: OverflowBox(
                                    key: _emojiKeys[index],
                                    maxWidth: 56,
                                    maxHeight: 76,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutBack,
                                      transform: isHovered
                                          ? (Matrix4.identity()
                                              ..setTranslationRaw(
                                                0.0,
                                                -20.0,
                                                0.0,
                                              ))
                                          : Matrix4.identity(),
                                      transformAlignment: Alignment.center,
                                      child: AnimatedScale(
                                        scale: isHovered ? 1.7 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOutBack,
                                        child: _buildEmojiWidget(index, 28),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  final int likes;
  final int views;
  final String postId;
  final bool isDark;
  final String? userReaction;
  final bool isOverlay;

  const _ReactionSummary({
    required this.likes,
    required this.views,
    required this.postId,
    required this.isDark,
    this.userReaction,
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: LikeService.instance.getPostReactions(postId),
      builder: (context, snapshot) {
        final emojisToShow = <String>[];

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final Set<String> uniqueEmojis = {};
          for (final reactor in snapshot.data!) {
            final emoji = reactor['reaction'] as String? ?? '❤';
            if (uniqueEmojis.add(emoji)) {
              emojisToShow.add(emoji);
              if (emojisToShow.length == 3) break;
            }
          }
        } else if (likes > 0 || userReaction != null) {
          // Fallback while loading ONLY if there are likes
          if (userReaction != null) {
            emojisToShow.add(userReaction!);
          } else if (likes > 0) {
            emojisToShow.add('👍');
            if (likes >= 2) emojisToShow.add('❤');
            if (likes >= 3) emojisToShow.add('🔥');
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Views Button
            GestureDetector(
              onTap: () {
                KnockHaptics.selection();
                PostAnalyticsSheet.show(
                  context,
                  postId: postId,
                  initialIndex: 0,
                  userReaction: userReaction,
                  totalViews: views,
                );
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 26,
                width: 26,
                child: Center(
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter: _CustomEyePainter(
                      color: isOverlay
                          ? Colors.white.withValues(alpha: 0.95)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
            
            if (emojisToShow.isNotEmpty) ...[
              const SizedBox(width: 4),
              
              // Reactions Button — overlapping emoji chips
              GestureDetector(
                onTap: () {
                  KnockHaptics.selection();
                  PostAnalyticsSheet.show(
                    context,
                    postId: postId,
                    initialIndex: 1,
                    userReaction: userReaction,
                    totalViews: views,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 26.0 + (emojisToShow.length - 1) * 16.0,
                  height: 26,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(emojisToShow.length, (index) {
                      final emoji = emojisToShow[index];
                      
                      return Positioned(
                        left: index * 16.0,
                        top: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isOverlay
                                ? Colors.black.withValues(alpha: 0.45)
                                : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isOverlay
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 14, height: 1.1),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CustomEyePainter extends CustomPainter {
  final Color color;

  _CustomEyePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Top arch
    final path = Path();
    path.moveTo(strokeWidth / 2, size.height * 0.45);
    path.quadraticBezierTo(
      size.width * 0.5,
      0.0, // control point to create a gentle curve
      size.width - (strokeWidth / 2),
      size.height * 0.45,
    );
    canvas.drawPath(path, strokePaint);

    // Draw perfectly solid pupil
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.66),
      size.width * 0.21,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CustomEyePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern curved reply arrow icon — premium minimal design
// EXACT geometrical implementation based on specified constraints.
// ─────────────────────────────────────────────────────────────────────────────
class _ReplyIconPainter extends CustomPainter {
  final Color color;

  const _ReplyIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75 // Matches visual density of default Material icons
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path();

    // 1. ARROWHEAD (45° chevron)
    // Tip at x=15%, y=25%
    final tipX = w * 0.15;
    final tipY = h * 0.25;
    final chevronDx = w * 0.11;
    final chevronDy = h * 0.11;

    path.moveTo(tipX + chevronDx, tipY - chevronDy);
    path.lineTo(tipX, tipY);
    path.lineTo(tipX + chevronDx, tipY + chevronDy);

    // 2. TOP HORIZONTAL LINE
    // Starts at arrowhead, goes perfectly horizontal to the arc start.
    // To be mathematically tangent to the semicircle, it ends exactly at the arc's center X.
    path.moveTo(tipX, tipY);
    
    // 3. RIGHT ARC (perfect semicircle)
    // Shifting center to ~65% to make the top horizontal line MUCH longer,
    // properly filling the icon canvas space.
    final arcCenterX = w * 0.65;
    final arcCenterY = h * 0.545;
    final arcRadius = h * 0.295;

    path.lineTo(arcCenterX, tipY); // tipY is exactly arcCenterY - arcRadius

    path.arcToPoint(
      Offset(arcCenterX, arcCenterY + arcRadius), // Ends at exact bottom of the circle
      radius: Radius.circular(arcRadius),
      clockwise: true,
    );

    // 4. BOTTOM TAIL
    // Very short, perfectly horizontal. Ends at x=37%
    final tailEndX = w * 0.37;
    path.lineTo(tailEndX, arcCenterY + arcRadius);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReplyIconPainter oldDelegate) =>

      color != oldDelegate.color;
}
