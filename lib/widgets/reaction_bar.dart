import 'package:flutter/material.dart';

/// Emoji data for the reaction popup
class ReactionEmoji {
  final String emoji;
  final String label;

  const ReactionEmoji(this.emoji, this.label);
}

const List<ReactionEmoji> _reactions = [
  ReactionEmoji('👍', 'Like'),
  ReactionEmoji('❤️', 'Love'),
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

  const ReactionBar({
    super.key,
    this.doubleTapped = false,
    this.onDoubleTapHandled,
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
      _selectWithAnimation('❤️');
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
    if (_selectedEmoji != null) {
      // Already reacted → un-react
      setState(() => _selectedEmoji = null);
    } else {
      _selectWithAnimation('❤️');
    }
  }

  /// Select emoji with bounce animation
  void _selectWithAnimation(String emoji) {
    setState(() => _selectedEmoji = emoji);
    _heartController.forward(from: 0);
  }

  // ── Long press drag logic (Facebook-style) ──


  void _onLongPressStart(LongPressStartDetails details) {
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main reaction bar row ──
        Row(
          children: [
            // Reaction button — tap or long press
            GestureDetector(
              onTap: _onTapReaction,
              onLongPressStart: _onLongPressStart,
              onLongPressMoveUpdate: _onLongPressMoveUpdate,
              onLongPressEnd: _onLongPressEnd,
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xfff2f2f2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _selectedEmoji != null
                      ? ScaleTransition(
                          scale: _heartScale,
                          child: Text(
                            _selectedEmoji!,
                            style: const TextStyle(fontSize: 20),
                          ),
                        )
                      : Image.asset(
                          "assets/reaction_default.png",
                          width: 22,
                        ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Comment button
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xfff2f2f2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: Colors.black54,
              ),
            ),

            const SizedBox(width: 10),

            // Share button
            const Icon(
              Icons.share_outlined,
              color: Colors.black,
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
              child: Material(
                elevation: 6,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(30),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_reactions.length, (index) {
                      final isHovered = _hoveredIndex == index;
                      return AnimatedContainer(
                        key: _emojiKeys[index],
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        transform: isHovered
                            ? (Matrix4.identity()
                              ..setTranslationRaw(0.0, -16.0, 0.0))
                            : Matrix4.identity(),
                        transformAlignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Label above hovered emoji
                            AnimatedOpacity(
                              opacity: isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color.fromRGBO(0, 0, 0, 0.75),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _reactions[index].label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            // Emoji
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: isHovered ? 36 : 26,
                              ),
                              child: Text(_reactions[index].emoji),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}