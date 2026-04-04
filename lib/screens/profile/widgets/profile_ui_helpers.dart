import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared UI helpers used across profile widgets and screens.

// ─── Empty-state placeholder ─────────────────────────────────────────────────

class ProfileEmptySection extends StatefulWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final List<Color>? gradientColors;
  final TabController? tabController;
  final int? tabIndex;

  const ProfileEmptySection({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.gradientColors,
    this.tabController,
    this.tabIndex,
  });

  @override
  State<ProfileEmptySection> createState() => _ProfileEmptySectionState();
}

class _ProfileEmptySectionState extends State<ProfileEmptySection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _cardFadeAnim;
  late final Animation<Offset> _cardSlideAnim;
  late final Animation<double> _titleFadeAnim;
  late final Animation<Offset> _titleSlideAnim;
  late final Animation<double> _subtitleFadeAnim;
  late final Animation<Offset> _subtitleSlideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Card & Ring enter first
    _cardFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );
    _cardSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    // Title subtly slides and fades in slightly after
    _titleFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    );
    _titleSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));

    // Subtitle subtly slides and fades in slightly after title
    _subtitleFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );
    _subtitleSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    if (widget.tabController != null && widget.tabIndex != null) {
      widget.tabController!.animation?.addListener(_onTabAnimation);
      _onTabAnimation();
    } else {
      _animController.forward();
    }
  }

  void _onTabAnimation() {
    if (!mounted) return;
    
    // Check if this tab is the currently active/visible one
    // animation.value ranges from 0.0 to length-1.
    // When swipe crosses exactly halfway, value.round() equals tabIndex
    final activeIndex = widget.tabController!.animation?.value.round();
    
    if (activeIndex == widget.tabIndex) {
      if (_animController.status == AnimationStatus.dismissed) {
        _animController.forward();
      }
    } else {
      // If we are significantly scrolled away, reset the animation
      // We use a small threshold so it doesn't reset over tiny pans
      final distance = (widget.tabController!.animation!.value - widget.tabIndex!).abs();
      if (distance > 0.4 && _animController.status != AnimationStatus.dismissed) {
        _animController.reset();
      }
    }
  }

  @override
  void dispose() {
    widget.tabController?.animation?.removeListener(_onTabAnimation);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card colors — matching PrivateLockOverlay style
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final borderColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);

    // Default neutral gradient when none specified
    final colors = widget.gradientColors ??
        (isDark
            ? [Colors.white24, Colors.white12]
            : [Colors.black12, Colors.black.withValues(alpha: 0.06)]);

    final iconColor = isDark ? Colors.white54 : Colors.black38;
    final titleColor = isDark ? Colors.white70 : Colors.black54;
    final subtitleColor = isDark ? Colors.white38 : Colors.black38;

    return FadeTransition(
      opacity: _cardFadeAnim,
      child: SlideTransition(
        position: _cardSlideAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Gradient ring with icon ───────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardBg,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 32,
                    color: iconColor,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── Title ────────────────────────────────────────────────
              FadeTransition(
                opacity: _titleFadeAnim,
                child: SlideTransition(
                  position: _titleSlideAnim,
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),

              // ── Subtitle ────────────────────────────────────────────
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _subtitleFadeAnim,
                  child: SlideTransition(
                    position: _subtitleSlideAnim,
                    child: Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Animated Tab Bar ─────────────────────────────────────────────────

class ProfileAnimatedTabBar extends StatefulWidget {
  final TabController controller;
  final List<String> labels;
  final Color activeColor;
  final Color inactiveColor;
  final Color backgroundColor;

  const ProfileAnimatedTabBar({
    super.key,
    required this.controller,
    required this.labels,
    required this.activeColor,
    required this.inactiveColor,
    required this.backgroundColor,
  });

  @override
  State<ProfileAnimatedTabBar> createState() => _ProfileAnimatedTabBarState();
}

class _ProfileAnimatedTabBarState extends State<ProfileAnimatedTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pillController;
  late Animation<double> _pillAnim;
  int _previousIndex = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller.index;
    _previousIndex = widget.controller.index;
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pillAnim = CurvedAnimation(
      parent: _pillController,
      curve: Curves.easeInOutCubicEmphasized,
    );
    widget.controller.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (widget.controller.indexIsChanging) {
      if (mounted) {
        setState(() {
          _previousIndex = _currentIndex;
          _currentIndex = widget.controller.index;
        });
        _pillController.forward(from: 0);
      }
    } else {
      if (_currentIndex != widget.controller.index) {
        if (mounted) {
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = widget.controller.index;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    _pillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.backgroundColor == Colors.black ||
        Theme.of(context).brightness == Brightness.dark;
    final divColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFEEEEEE);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border(
          bottom: BorderSide(color: divColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        final tabCount = widget.labels.length;
        final totalWidth = constraints.maxWidth;
        final tabWidth = totalWidth / tabCount;

        return AnimatedBuilder(
          animation: Listenable.merge([widget.controller.animation, _pillAnim]),
          builder: (context, _) {
            double pillLeft;
            if (widget.controller.indexIsChanging) {
              final fromX = _previousIndex * tabWidth;
              final toX = _currentIndex * tabWidth;
              pillLeft = lerpDouble(fromX, toX, _pillAnim.value)!;
            } else {
              final animValue = widget.controller.animation?.value ?? 0.0;
              pillLeft = animValue * tabWidth;
            }

            return SizedBox(
              height: 40,
              child: Stack(
                children: [
                  // ── Sliding pill ──────────────────────────────────────────
                  Positioned(
                    left: pillLeft + 6,
                    top: 0,
                    width: tabWidth - 12,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // ── Labels ────────────────────────────────────────────────
                  Row(
                    children: List.generate(tabCount, (i) {
                      final isSelected = widget.controller.index == i;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (widget.controller.index == i) return;
                          HapticFeedback.selectionClick();
                          widget.controller.animateTo(i);
                        },
                        child: SizedBox(
                          width: tabWidth,
                          height: 40,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeInOutCubic,
                              style: TextStyle(
                                fontSize: isSelected ? 14.5 : 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? widget.activeColor
                                    : widget.inactiveColor,
                                letterSpacing: isSelected ? -0.4 : 0,
                              ),
                              child: Text(widget.labels[i]),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

// Tiny helper — avoids importing dart:math just for lerp
double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

// ─── Sticky animated tab bar delegate ───────────────────────────────────────

class ProfileStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  final Color bg;

  const ProfileStickyTabBarDelegate(
    this.tabBar, {
    required this.bg,
    // kept for backward compat but no longer draws a divider
    Color? divColor,
  });

  static const double _height = 57.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: bg, child: tabBar);
  }

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  bool shouldRebuild(ProfileStickyTabBarDelegate old) =>
      old.tabBar != tabBar || old.bg != bg;
}

// ─── Settings row ─────────────────────────────────────────────────────────────

class ProfileSettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ProfileSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
