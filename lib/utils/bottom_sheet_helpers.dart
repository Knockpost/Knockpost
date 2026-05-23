import 'package:flutter/material.dart';

/// Wraps bottom sheet content to extend behind the system navigation bar.
/// Use this inside `showModalBottomSheet(builder: ...)`.
/// 
/// This works by getting the system navigation bar height (viewPadding.bottom)
/// and appending a solid Container of that height to the bottom of the sheet,
/// ensuring that the transparent system nav bar has a solid background behind it.
/// 
/// Note: Ensure the `showModalBottomSheet` does NOT use `SafeArea(top: false)` 
/// or similar wrappers around the builder, as this helper handles the bottom padding.
class BottomSheetNavBarFill extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const BottomSheetNavBarFill({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Default matching the standard bottom sheet backgrounds in the app
    final fillColor = backgroundColor ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        Container(
          color: fillColor,
          height: bottomPadding,
        ),
      ],
    );
  }
}
