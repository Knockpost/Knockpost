import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared UI helpers used across profile widgets and screens.

// ─── Empty-state placeholder ─────────────────────────────────────────────────

class ProfileEmptySection extends StatelessWidget {
  final IconData icon;
  final String message;

  const ProfileEmptySection({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 38, color: isDark ? Colors.white30 : Colors.black26),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white38 : Colors.black38,
              height: 1.5,
            ),
          ),
        ],
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

  @override
  void initState() {
    super.initState();
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
    if (!widget.controller.indexIsChanging) return;
    setState(() => _previousIndex = widget.controller.previousIndex);
    _pillController.forward(from: 0);
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
          animation: _pillAnim,
          builder: (context, _) {
            final currentIndex = widget.controller.index;
            final fromX = _previousIndex * tabWidth;
            final toX = currentIndex * tabWidth;
            final pillLeft = lerpDouble(fromX, toX, _pillAnim.value)!;

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
