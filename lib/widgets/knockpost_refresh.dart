import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KnockpostRefreshIndicator
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
// The indicator is a thin open-arc ring (Knockpost-branded spinner).
// ─────────────────────────────────────────────────────────────────────────────

class KnockpostRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const KnockpostRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<KnockpostRefreshIndicator> createState() =>
      _KnockpostRefreshIndicatorState();
}

class _KnockpostRefreshIndicatorState extends State<KnockpostRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const double _triggerDistance = 100.0; // px to trigger refresh
  static const double _indicatorSize = 28.0;
  static const double _maxDisplacement = 70.0; // max visible drop distance

  double _dragOffset = 0;
  bool _isRefreshing = false;
  bool _isDragging = false;

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

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _spinController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spinController.stop();
        // Elegant exit: animate offset back to 0
        setState(() {
          _isRefreshing = false;
          _dragOffset = 0;
        });
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Only handle overscroll at the very top
    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        !_isRefreshing) {
      // Negative overscroll = pulling down from the top
      setState(() {
        _isDragging = true;
        _dragOffset += -notification.overscroll * 0.6; // damping
      });
      return true;
    }

    if (notification is ScrollUpdateNotification &&
        _isDragging &&
        !_isRefreshing) {
      // If the user is scrolling back up while dragging
      if (notification.scrollDelta != null && notification.scrollDelta! > 0) {
        setState(() {
          _dragOffset = (_dragOffset - notification.scrollDelta!).clamp(0, double.infinity);
        });
      }
    }

    if (notification is ScrollEndNotification && _isDragging) {
      _isDragging = false;
      if (_dragOffset >= _triggerDistance && !_isRefreshing) {
        _startRefresh();
      } else if (!_isRefreshing) {
        setState(() => _dragOffset = 0);
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arcColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.40);

    return Stack(
      children: [
        // ── Scrollable child ──
        NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: widget.child,
        ),

        // ── Custom indicator ──
        if (_dragOffset > 0 || _isRefreshing)
          Positioned(
            top: 0,
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
                  child: _isRefreshing
                      ? AnimatedBuilder(
                          animation: _spinController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size.square(_indicatorSize),
                              painter: _ArcSpinnerPainter(
                                progress: _spinController.value,
                                color: arcColor,
                              ),
                            );
                          },
                        )
                      : CustomPaint(
                          size: const Size.square(_indicatorSize),
                          painter: _ArcPullPainter(
                            pullProgress: _pullProgress,
                            color: arcColor,
                          ),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ArcPullPainter — draws a thin arc that grows as the user pulls down.
// At 0% pull → nothing. At 100% pull → full 270° open arc.
// ─────────────────────────────────────────────────────────────────────────────
class _ArcPullPainter extends CustomPainter {
  final double pullProgress; // 0..1
  final Color color;

  const _ArcPullPainter({required this.pullProgress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (pullProgress <= 0) return;

    final paint = Paint()
      ..color = color.withValues(alpha: color.a * pullProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - paint.strokeWidth) / 2;

    // Arc sweep grows from 0° to 270° as user pulls
    final sweepAngle = math.pi * 1.5 * pullProgress;
    // Start from top (−90°)
    const startAngle = -math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPullPainter oldDelegate) =>
      pullProgress != oldDelegate.pullProgress || color != oldDelegate.color;
}

// ─────────────────────────────────────────────────────────────────────────────
// KnockpostLoadingIndicator
//
// Standalone branded loading spinner for initial-load / waiting states.
// Replaces all default CircularProgressIndicator instances.
// Thin open-arc ring with smooth continuous rotation.
// ─────────────────────────────────────────────────────────────────────────────

class KnockpostLoadingIndicator extends StatefulWidget {
  final double size;

  const KnockpostLoadingIndicator({super.key, this.size = 28});

  @override
  State<KnockpostLoadingIndicator> createState() =>
      _KnockpostLoadingIndicatorState();
}

class _KnockpostLoadingIndicatorState extends State<KnockpostLoadingIndicator>
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
            painter: _ArcSpinnerPainter(
              progress: _controller.value,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.35),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ArcSpinnerPainter — draws a thin open-arc ring that rotates smoothly.
// Used by both the pull-to-refresh (during spin phase) and the standalone
// loading indicator.
// ─────────────────────────────────────────────────────────────────────────────
class _ArcSpinnerPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  const _ArcSpinnerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - paint.strokeWidth) / 2;

    // Arc sweep: ~270° (leaves a visible gap for premium feel)
    const sweepAngle = math.pi * 1.5;

    // Smooth rotation
    final startAngle = progress * math.pi * 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcSpinnerPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
