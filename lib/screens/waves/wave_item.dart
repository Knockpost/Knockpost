import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'widgets/wave_comment_sheet.dart';
import 'widgets/share_sheet.dart';
import 'widgets/more_options_sheet.dart';
import '../profile/other_profile_screen.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';

class WaveItem extends StatefulWidget {
  final String videoUrl;
  final String username;
  final String caption;
  final bool isActive;
  final double bottomPadding;

  const WaveItem({
    super.key,
    required this.videoUrl,
    required this.username,
    required this.caption,
    required this.isActive,
    this.bottomPadding = 0,
  });

  @override
  State<WaveItem> createState() => _WaveItemState();
}

class _WaveItemState extends State<WaveItem> with TickerProviderStateMixin {
  late VideoPlayerController _controller;

  bool isPlaying = true;
  bool showHeart = false;
  bool _doubleTapped = false;
  bool _isKnocked = false;
  bool _showBlackFlash = false;

  /// Like animation
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;
  late Animation<double> _heartOpacityAnim;

  /// Play/pause icon animation
  late AnimationController _playPauseAnimController;
  late Animation<double> _playPauseOpacity;

  @override
  void initState() {
    super.initState();

    /// Heart animation setup
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _heartScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.easeOut,
    ));

    _heartOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.easeOut,
    ));

    /// Play/pause fade
    _playPauseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _playPauseOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _playPauseAnimController,
        curve: Curves.easeInOut,
      ),
    );

    /// Video
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.setLooping(true);
        if (widget.isActive) {
          _controller.play();
        } else {
          _controller.pause();
        }
      }).catchError((e) {
        debugPrint("Video initialization error: $e");
      });
  }

  @override
  void didUpdateWidget(covariant WaveItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.value.isInitialized) return;

    if (widget.isActive) {
      _controller.play();
      isPlaying = true;
      _playPauseAnimController.reverse();
    } else {
      _controller.pause();
      isPlaying = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _heartAnimController.dispose();
    _playPauseAnimController.dispose();
    super.dispose();
  }

  void togglePlay() {
    if (!_controller.value.isInitialized) return;

    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        isPlaying = false;
        _playPauseAnimController.forward();
      } else {
        _controller.play();
        isPlaying = true;
        _playPauseAnimController.reverse();
      }
    });
  }

  void _toggleKnock() {
    KnockHaptics.tap();
    if (_isKnocked) {
      setState(() => _isKnocked = false);
      return;
    }

    setState(() {
      _isKnocked = true;
      _showBlackFlash = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _showBlackFlash = false);
      }
    });
  }

  void handleDoubleTap() {
    KnockHaptics.impact();
    setState(() {
      _doubleTapped = true;
      showHeart = true;
    });

    _heartAnimController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => showHeart = false);
      }
    });
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  @override
  Widget build(BuildContext context) {
    Color knockBgColor;
    Color knockTextColor;

    if (!_isKnocked) {
      knockBgColor = const Color(0xfff2f2f2);
      knockTextColor = Colors.black;
    } else if (_showBlackFlash) {
      knockBgColor = Colors.black;
      knockTextColor = Colors.white;
    } else {
      knockBgColor = const Color(0xfff2f2f2);
      knockTextColor = Colors.black;
    }

    return GestureDetector(
      onTap: togglePlay,
      onDoubleTap: handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// 🎥 VIDEO
          _controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),

          /// 🌑 GRADIENT OVERLAY (multi-stop for premium feel)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          /// ❤️ DOUBLE TAP HEART (pro animation)
          if (showHeart)
            Center(
              child: AnimatedBuilder(
                animation: _heartAnimController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacityAnim.value,
                    child: Transform.scale(
                      scale: _heartScaleAnim.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 110,
                      ),
                    ),
                  );
                },
              ),
            ),

          /// ❤️ RIGHT ACTIONS
          Positioned(
            right: 12,
            bottom: 100 + widget.bottomPadding,
            child: Column(
              children: [
                /// ❤️ EMOJI REACTION (Replaces simple Like)
                WaveReactionButton(
                  doubleTapped: _doubleTapped,
                  onDoubleTapHandled: _onDoubleTapHandled,
                ),

                const SizedBox(height: 20),

                /// 💬 COMMENT
                _AnimatedActionButton(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => WaveCommentSheet(
                        creatorUsername: widget.username,
                      ),
                    );
                  },
                  icon: Icons.mode_comment_outlined,
                  label: null,
                  color: Colors.white,
                ),

                const SizedBox(height: 20),

                /// 📤 SHARE
                _AnimatedActionButton(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ShareSheet(
                        videoUrl: widget.videoUrl,
                        username: widget.username,
                        caption: widget.caption,
                      ),
                    );
                  },
                  icon: Icons.send_outlined,
                  label: "Share",
                  color: Colors.white,
                ),

                const SizedBox(height: 20),

                /// ⋮ MORE OPTIONS
                _AnimatedActionButton(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => MoreOptionsSheet(
                        username: widget.username,
                      ),
                    );
                  },
                  icon: Icons.more_horiz_rounded,
                  label: "More",
                  color: Colors.white,
                ),
              ],
            ),
          ),

          /// 👤 BOTTOM INFO
          Positioned(
            left: 14,
            bottom: 20 + widget.bottomPadding,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Username Row
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtherProfileScreen(
                            user: demoAryaLayek, posts: demoOwnPosts),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      /// Avatar with gradient ring
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade400,
                              Colors.orange.shade400,
                            ],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey.shade900,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// Username
                      Text(
                        "@${widget.username}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// Knock Button
                      GestureDetector(
                        onTap: () {
                          // Prevent toggling play/pause when tapping Knock
                          _toggleKnock();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: knockBgColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: knockTextColor,
                            ),
                            child: Text(_isKnocked ? "Knocked" : "Knock"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                /// Caption
                Text(
                  widget.caption,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                /// 🎵 Music bar
                Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Original Audio — @${widget.username}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// 💿 SPINNING ALBUM DISC (unique KnockPost touch)
          Positioned(
            right: 14,
            bottom: 24 + widget.bottomPadding,
            child: _SpinningDisc(isPlaying: isPlaying),
          ),

          /// ⏸ PLAY ICON (animated fade in/out)
          FadeTransition(
            opacity: _playPauseOpacity,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),

          /// 📏 VIDEO PROGRESS BAR
          if (_controller.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 4, // Make progress bar clearly visible
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated Action Button with bounce effect
class _AnimatedActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String? label;
  final Color color;

  const _AnimatedActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _bounceController.reset();
        _bounceController.forward();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min, // Ensures tight vertical fit
            children: [
              Transform.scale(
                scale: _bounceAnim.value,
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 30,
                ),
              ),
              if (widget.label != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Spinning album disc (unique KnockPost touch)
class _SpinningDisc extends StatefulWidget {
  final bool isPlaying;

  const _SpinningDisc({required this.isPlaying});

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    if (widget.isPlaying) {
      _discController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SpinningDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_discController.isAnimating) {
      _discController.repeat();
    } else if (!widget.isPlaying && _discController.isAnimating) {
      _discController.stop();
    }
  }

  @override
  void dispose() {
    _discController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _discController,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade700,
            width: 6,
          ),
          color: Colors.grey.shade900,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade800,
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: 14,
          ),
        ),
      ),
    );
  }
}

class WaveReactionButton extends StatefulWidget {
  final bool doubleTapped;
  final VoidCallback? onDoubleTapHandled;

  const WaveReactionButton({
    super.key,
    this.doubleTapped = false,
    this.onDoubleTapHandled,
  });

  @override
  State<WaveReactionButton> createState() => _WaveReactionButtonState();
}

class _WaveReactionButtonState extends State<WaveReactionButton>
    with TickerProviderStateMixin {
  String? _selectedEmoji;

  // ── Popup state ──
  bool _showPopup = false;
  int _hoveredIndex = -1;
  final List<String> _reactions = ['👍', '❤', '🥰', '😂', '😮', '😢', '🔥'];
  final List<GlobalKey> _emojiKeys =
      List.generate(7, (_) => GlobalKey());

  // ── Animations ──
  late AnimationController _popupController;
  late Animation<double> _popupScale;

  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();

    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _popupScale = CurvedAnimation(
      parent: _popupController,
      curve: Curves.elasticOut,
    );

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
  void didUpdateWidget(covariant WaveReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.doubleTapped && !oldWidget.doubleTapped) {
      _selectWithAnimation('❤');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDoubleTapHandled?.call();
      });
    }
  }

  @override
  void dispose() {
    _popupController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  void _onTapReaction() {
    KnockHaptics.tap();
    if (_selectedEmoji != null) {
      setState(() => _selectedEmoji = null);
    } else {
      _selectWithAnimation('❤');
    }
  }

  void _selectWithAnimation(String emoji) {
    KnockHaptics.impact();
    setState(() => _selectedEmoji = emoji);
    _heartController.forward(from: 0);
  }

  Widget _buildEmojiWidget(int index, double size) {
    final emoji = _reactions[index];
    if (emoji == '❤') {
      return Icon(Icons.favorite, color: const Color(0xFFED4956), size: size + 4);
    }
    return Text(emoji, style: TextStyle(fontSize: size));
  }

  Widget _buildSelectedWidget(String emoji, double size) {
    if (emoji == '❤') {
      return Icon(Icons.favorite, color: const Color(0xFFED4956), size: size + 4);
    }
    return Text(emoji, style: TextStyle(fontSize: size));
  }

  void _onLongPressStart(LongPressStartDetails details) {
    KnockHaptics.vibrate();
    setState(() {
      _showPopup = true;
      _hoveredIndex = -1;
    });
    _popupController.forward(from: 0);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
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
    if (_hoveredIndex != -1) {
      setState(() => _hoveredIndex = -1);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_hoveredIndex >= 0 && _hoveredIndex < _reactions.length) {
      _selectWithAnimation(_reactions[_hoveredIndex]);
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
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _onTapReaction,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: _onLongPressEnd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 38,
                child: Center(
                  child: _selectedEmoji != null
                      ? ScaleTransition(
                          scale: _heartScale,
                          child: _buildSelectedWidget(_selectedEmoji!, 30),
                        )
                      : const Icon(
                          Icons.favorite_border,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),

        if (_showPopup)
          Positioned(
            right: 50,
            bottom: 0,
            child: ScaleTransition(
              scale: _popupScale,
              alignment: Alignment.bottomRight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
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

