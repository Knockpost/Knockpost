import 'package:flutter/material.dart';

/// A transparent, non-interactive widget that draws a solid background color
/// behind the Android system navigation bar area.
///
/// On Android 15+ the system nav bar is always transparent regardless of
/// [SystemUiOverlayStyle.systemNavigationBarColor]. Wrapping a [Scaffold]
/// with a [Stack] containing this widget at `bottom: 0` ensures the nav bar
/// area never looks see-through.
///
/// Usage:
/// ```dart
/// Stack(children: [
///   Scaffold(...),
///   SystemNavBarFill(color: bg),
/// ])
/// ```
class SystemNavBarFill extends StatelessWidget {
  final Color color;

  const SystemNavBarFill({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    if (bottomPadding == 0) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          height: bottomPadding,
          color: color,
        ),
      ),
    );
  }
}
