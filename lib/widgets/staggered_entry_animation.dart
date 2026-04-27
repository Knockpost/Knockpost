import 'package:flutter/material.dart';

class StaggeredEntryAnimation extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Offset offset;

  const StaggeredEntryAnimation({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
    this.offset = const Offset(0, 0.15), // Using fractions for SlideTransition
  });

  @override
  State<StaggeredEntryAnimation> createState() => _StaggeredEntryAnimationState();
}

class _StaggeredEntryAnimationState extends State<StaggeredEntryAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(curve);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(curve);

    // Provide a small base delay to coordinate with page swiping,
    // plus the staggered delay.
    final totalDelayMs = 60 + (widget.delay.inMilliseconds * widget.index);
    Future.delayed(Duration(milliseconds: totalDelayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Avoid AnimatedBuilder + Transform for better performance. 
    // Transition widgets compile down to Render layer shifts (no layout rebuilds!)
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

