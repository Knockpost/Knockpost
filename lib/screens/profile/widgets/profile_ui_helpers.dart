import 'package:flutter/material.dart';

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

// ─── Sticky TabBar delegate ───────────────────────────────────────────────────

class ProfileStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bg;
  final Color divColor;

  const ProfileStickyTabBarDelegate(
    this.tabBar, {
    required this.bg,
    required this.divColor,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          Divider(height: 1, color: divColor),
        ],
      ),
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

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
