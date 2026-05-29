import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/haptic_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KnockPostRefreshIndicator
//
// Fully custom Instagram-style pull-to-refresh.
// NO Material RefreshIndicator used — 100% custom visuals.
//
// Pull behavior:
//   1. User drags down from top → thin arc progressively reveals
//   2. Pull past threshold → arc completes, haptic feedback
//   3. Release → arc spins smoothly during refresh
//   4. Refresh done → arc fades out + slides up elegantly
//
// The indicator is a thin open-arc ring (KnockPost-branded spinner).
// ─────────────────────────────────────────────────────────────────────────────

class KnockPostRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const KnockPostRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<KnockPostRefreshIndicator> createState() =>
      _KnockPostRefreshIndicatorState();
}

class _KnockPostRefreshIndicatorState extends State<KnockPostRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const double _triggerDistance = 100.0; // px to trigger refresh
  static const double _maxDisplacement = 70.0; // max visible drop distance
  static const Duration _safetyTimeout = Duration(seconds: 15);

  double _dragOffset = 0;
  bool _isRefreshing = false;
  bool _isDragging = false;
  bool _hasTriggeredHaptic = false;
  int _lastHapticTick = 0; // tracks pull distance for gear-winding haptics

  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  /// How far the indicator has traveled (0..1 clamped).
  double get _pullProgress =>
      (_dragOffset / _triggerDistance).clamp(0.0, 1.0);

  /// Visible vertical offset for the indicator container.
  double get _indicatorOffset {
    if (_isRefreshing) return _maxDisplacement;
    return (_dragOffset.clamp(0, _maxDisplacement * 1.4) *
            Curves.easeOutCubic.transform(
              (_dragOffset / (_maxDisplacement * 1.4)).clamp(0.0, 1.0),
            ))
        .clamp(0.0, _maxDisplacement);
  }

  /// Reset all drag state cleanly.
  void _resetDragState() {
    _isDragging = false;
    _hasTriggeredHaptic = false;
    _lastHapticTick = 0;
    if (!_isRefreshing) {
      setState(() => _dragOffset = 0);
    }
  }

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _spinController.repeat();

    try {
      await widget.onRefresh().timeout(
        _safetyTimeout,
        onTimeout: () {
          debugPrint('[KnockPostRefresh] onRefresh timed out after $_safetyTimeout');
        },
      );
    } catch (e) {
      debugPrint('[KnockPostRefresh] onRefresh error: $e');
    } finally {
      if (mounted) {
        _spinController.stop();
        setState(() {
          _isRefreshing = false;
          _dragOffset = 0;
          _isDragging = false;
        });
      }
    }
  }

  /// Called when the user lifts their finger. Acts as a safety fallback
  /// in case ScrollEndNotification is missed (common with NestedScrollView).
  void _onPointerUp() {
    if (!_isDragging || _isRefreshing) return;

    // Defer slightly to let ScrollEndNotification arrive first
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_isDragging) return;
      // ScrollEndNotification didn't arrive — handle manually
      _isDragging = false;
      _hasTriggeredHaptic = false;
      _lastHapticTick = 0;
      if (_dragOffset >= _triggerDistance && !_isRefreshing) {
        KnockHaptics.impact();
        _startRefresh();
      } else if (!_isRefreshing) {
        setState(() => _dragOffset = 0);
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // ── Handle OverscrollNotification (ClampingScrollPhysics) ──
    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        !_isRefreshing) {
      setState(() {
        _isDragging = true;
        _dragOffset += -notification.overscroll * 0.6;
      });
      _checkHapticThreshold();
      return true;
    }

    // ── Handle BouncingScrollPhysics (no OverscrollNotification emitted) ──
    // Detect overscroll by checking: position is at top edge + scroll is going down
    if (notification is ScrollUpdateNotification && !_isRefreshing) {
      final pos = notification.metrics;
      final delta = notification.scrollDelta ?? 0;

      // User is at the very top and pulling further down
      if (pos.pixels <= pos.minScrollExtent && delta < 0) {
        setState(() {
          _isDragging = true;
          _dragOffset += -delta * 0.6; // damping
        });
        _checkHapticThreshold();
        return true;
      }

      // User is scrolling back up while in pull state
      if (_isDragging && delta > 0) {
        setState(() {
          _dragOffset = (_dragOffset - delta).clamp(0.0, double.infinity);
        });
        if (_dragOffset <= 0) {
          _resetDragState();
        }
      }
    }

    // ── Handle scroll end ──
    if (notification is ScrollEndNotification && _isDragging) {
      _isDragging = false;
      _hasTriggeredHaptic = false;
      _lastHapticTick = 0;
      if (_dragOffset >= _triggerDistance && !_isRefreshing) {
        KnockHaptics.impact();
        _startRefresh();
      } else if (!_isRefreshing) {
        setState(() => _dragOffset = 0);
      }
    }

    return false;
  }

  /// Premium gear-winding haptic feedback while pulling.
  void _checkHapticThreshold() {
    // 1. Subtle ticks while pulling down (every 25px)
    int currentTick = (_dragOffset / 25.0).floor();
    if (currentTick > _lastHapticTick && _dragOffset < _triggerDistance) {
      _lastHapticTick = currentTick;
      KnockHaptics.selection(); // Light tick
    } else if (currentTick < _lastHapticTick) {
      _lastHapticTick = currentTick;
    }

    // 2. Solid pop when crossing the refresh threshold
    if (_dragOffset >= _triggerDistance && !_hasTriggeredHaptic) {
      _hasTriggeredHaptic = true;
      KnockHaptics.impact();
    } else if (_dragOffset < _triggerDistance && _hasTriggeredHaptic) {
      _hasTriggeredHaptic = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Listener(
      onPointerUp: (_) => _onPointerUp(),
      onPointerCancel: (_) => _onPointerUp(),
      child: Stack(
        children: [
          // ── Scrollable child ──
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: widget.child,
          ),

          // ── Custom indicator ──
          if (_dragOffset > 0 || _isRefreshing)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 60,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: _isRefreshing
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: _isRefreshing ? _maxDisplacement : _indicatorOffset,
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_pullProgress > 0.05 || _isRefreshing) ? 1.0 : 0.0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: (_pullProgress > 0.05 || _isRefreshing)
                        ? 0.7 + (_pullProgress * 0.3)
                        : 0.3,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AnimatedBuilder(
                        animation: _spinController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _ThreeDotPainter(
                              progress: _spinController.value,
                              pullProgress: _pullProgress,
                              isRefreshing: _isRefreshing,
                              isDark: isDark,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// KnockPostLoadingIndicator
//
// Standalone branded loading spinner for initial-load / waiting states.
// Replaces all default CircularProgressIndicator instances.
// Thin open-arc ring with smooth continuous rotation.
// ─────────────────────────────────────────────────────────────────────────────

class KnockPostLoadingIndicator extends StatefulWidget {
  final double size;

  const KnockPostLoadingIndicator({super.key, this.size = 44});

  @override
  State<KnockPostLoadingIndicator> createState() =>
      _KnockPostLoadingIndicatorState();
}

class _KnockPostLoadingIndicatorState extends State<KnockPostLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _ThreeDotPainter(
              progress: _controller.value,
              pullProgress: 1.0,
              isRefreshing: true,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _ThreeDotPainter — draws a minimal, premium 3-dot cluster animation.
// 3 circular dots arranged in a tight triangle that pulse sequentially.
// ─────────────────────────────────────────────────────────────────────────────
class _ThreeDotPainter extends CustomPainter {
  final double progress; // For spinning (0 to 1 repeatedly)
  final double pullProgress; // For pulling down (0 to 1)
  final bool isRefreshing;
  final bool isDark;

  const _ThreeDotPainter({
    required this.progress,
    required this.pullProgress,
    required this.isRefreshing,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = isDark ? Colors.white : Colors.black;

    // Scale dynamically based on canvas size
    final baseScale = size.width / 48.0;
    final scale = (isRefreshing ? 1.0 : pullProgress) * baseScale;
    if (scale <= 0) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Spacing between dots
    const double spacing = 12.0;
    
    // Draw a dot at a given index
    void drawDot(int index) {
      double r = 4.0; // constant base radius
      double dy = 0.0;
      
      if (isRefreshing) {
        // Horizontal wave bounce
        // Slower, more relaxed wave (using just progress instead of progress * 2)
        // Using - (index / 4.0) gives a natural left-to-right wave flow
        final double phase = (progress - (index / 4.0)) * math.pi * 2;
        // Math.sin gives -1 to 1. We multiply by amplitude.
        // dy is negative to move UP in canvas coordinates.
        dy = math.sin(phase) * 6.0; 
      }

      // x offset: index 0 -> -spacing, index 1 -> 0, index 2 -> spacing
      final dx = (index - 1) * spacing;
      
      canvas.drawCircle(Offset(dx, dy), r, dotPaint);
    }

    // 3 dots arranged horizontally
    drawDot(0);
    drawDot(1);
    drawDot(2);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThreeDotPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.pullProgress != pullProgress ||
           oldDelegate.isRefreshing != isRefreshing ||
           oldDelegate.isDark != isDark;
  }
}

