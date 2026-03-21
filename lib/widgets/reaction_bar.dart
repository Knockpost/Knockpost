import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../utils/haptic_helper.dart';
import 'comment_sheet.dart';

/// Emoji data for the reaction popup
class ReactionEmoji {
  final String emoji;
  final String label;

  const ReactionEmoji(this.emoji, this.label);
}

const List<ReactionEmoji> _reactions = [
  ReactionEmoji('👍', 'Like'),
  ReactionEmoji('❤', 'Love'),
  ReactionEmoji('🥰', 'Care'),
  ReactionEmoji('😂', 'Haha'),
  ReactionEmoji('😮', 'Wow'),
  ReactionEmoji('😢', 'Sad'),
  ReactionEmoji('🔥', 'Fire'),
];

class ReactionBar extends StatefulWidget {
  /// Triggered from PostCard double-tap
  final bool doubleTapped;
  final VoidCallback? onDoubleTapHandled;
  final String postId;
  final bool isPostOwner;

  const ReactionBar({
    super.key,
    this.doubleTapped = false,
    this.onDoubleTapHandled,
    this.postId = 'demo_post',
    this.isPostOwner = false,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar>
    with TickerProviderStateMixin {
  String? _selectedEmoji;

  // ── Popup state ──
  bool _showPopup = false;
  int _hoveredIndex = -1;
  final List<GlobalKey> _emojiKeys =
      List.generate(_reactions.length, (_) => GlobalKey());

  // ── Animations ──
  late AnimationController _popupController;
  late Animation<double> _popupScale;

  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();

    // Popup open/close animation
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _popupScale = CurvedAnimation(
      parent: _popupController,
      curve: Curves.elasticOut,
    );

    // Heart / emoji bounce animation on select
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(covariant ReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.doubleTapped && !oldWidget.doubleTapped) {
      _selectWithAnimation('❤');
      widget.onDoubleTapHandled?.call();
    }
  }

  @override
  void dispose() {
    _popupController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  /// Tap on reaction button → toggle ❤️
  void _onTapReaction() {
    KnockHaptics.tap();
    if (_selectedEmoji != null) {
      // Already reacted → un-react
      setState(() => _selectedEmoji = null);
    } else {
      _selectWithAnimation('❤');
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
    return Text(
      _reactions[index].emoji,
      style: TextStyle(fontSize: size),
    );
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
      final renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
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
      _selectWithAnimation(_reactions[_hoveredIndex].emoji);
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
    final bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main reaction bar row ──
        Row(
          children: [
            // Reaction button — tap or long press using RawGestureDetector due to older Flutter SDKs
            RawGestureDetector(
              gestures: {
                LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 150)),
                  (LongPressGestureRecognizer instance) {
                    instance
                      ..onLongPressStart = _onLongPressStart
                      ..onLongPressMoveUpdate = _onLongPressMoveUpdate
                      ..onLongPressEnd = _onLongPressEnd;
                  },
                ),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (TapGestureRecognizer instance) {
                    instance.onTap = _onTapReaction;
                  },
                ),
              },
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _selectedEmoji != null
                      ? ScaleTransition(
                          scale: _heartScale,
                          child: _buildSelectedWidget(_selectedEmoji!, 24),
                        )
                      : Image.asset(
                          "assets/reaction_default.png",
                          width: 24,
                        ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Comment button
            GestureDetector(
              onTap: () {
                CommentSheet.show(
                  context,
                  postId: widget.postId,
                  isPostOwner: widget.isPostOwner,
                );
              },
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Share button
            Icon(
              Icons.share_outlined,
              color: isDark ? Colors.white : Colors.black,
            ),
          ],
        ),

        // ── Floating emoji popup (above button) ──
        if (_showPopup)
          Positioned(
            bottom: 52,
            left: -8,
            child: ScaleTransition(
              scale: _popupScale,
              alignment: Alignment.bottomLeft,
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
                          blurRadius: 12,
                          offset: const Offset(0, 4),
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: OverflowBox(
                                key: _emojiKeys[index],
                                maxWidth: 56,
                                maxHeight: 76,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  transform: isHovered
                                      ? (Matrix4.identity()
                                        ..setTranslationRaw(0.0, -18.0, 0.0))
                                      : Matrix4.identity(),
                                  transformAlignment: Alignment.center,
                                  child: AnimatedScale(
                                    scale: isHovered ? 1.6 : 1.0,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    child: _buildEmojiWidget(index, 28),
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
