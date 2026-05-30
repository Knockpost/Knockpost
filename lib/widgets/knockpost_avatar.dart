import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Production-grade avatar widget for the entire Knockpost app.
///
/// Handles all image source types (network, asset, local file, null/empty)
/// with proper loading states, fade-in animations, error handling,
/// and dark/light mode support.
///
/// Usage:
/// ```dart
/// KnockpostAvatar(
///   url: user.avatarAsset,
///   radius: 22,
///   name: user.displayName,
/// )
/// ```
class KnockpostAvatar extends StatelessWidget {
  /// The image URL. Handles:
  /// - `null` or empty → fallback icon/initial
  /// - `http://` or `https://` → network image with caching
  /// - `assets/` → asset image (instant)
  /// - anything else → local file image
  final String? url;

  /// CircleAvatar radius (half the diameter).
  final double radius;

  /// Display name — first letter used as fallback when no image.
  /// If null, a person icon is shown instead.
  final String? name;

  const KnockpostAvatar({
    super.key,
    this.url,
    required this.radius,
    this.name,
  });

  bool get _hasUrl => url != null && url!.isNotEmpty;
  bool get _isNetwork => _hasUrl && url!.startsWith('http');
  bool get _isAsset => _hasUrl && url!.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    // ── No image URL ──
    if (!_hasUrl) {
      return _buildFallbackCircle(bgColor, isDark);
    }

    // ── Asset image (instant, no loading state needed) ──
    if (_isAsset) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: AssetImage(url!),
      );
    }

    // ── Local file image (instant) ──
    if (!_isNetwork) {
      final file = File(url!);
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: FileImage(file),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    // ── Network image: shimmer → fade-in → error fallback ──
    return _NetworkAvatar(
      url: url!,
      radius: radius,
      name: name,
      isDark: isDark,
      bgColor: bgColor,
    );
  }

  Widget _buildFallbackCircle(Color bgColor, bool isDark) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: _buildFallbackContent(isDark),
    );
  }

  Widget _buildFallbackContent(bool isDark) {
    if (name != null && name!.isNotEmpty) {
      return Text(
        name![0].toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white60 : Colors.black45,
        ),
      );
    }
    return Icon(
      Icons.person,
      size: radius * 1.1,
      color: Colors.grey.shade500,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network avatar with shimmer, fade-in, and error handling
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkAvatar extends StatelessWidget {
  final String url;
  final double radius;
  final String? name;
  final bool isDark;
  final Color bgColor;

  const _NetworkAvatar({
    required this.url,
    required this.radius,
    this.name,
    required this.isDark,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: ColoredBox(
          color: bgColor,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: diameter,
            height: diameter,
            fadeInDuration: const Duration(milliseconds: 280),
            fadeInCurve: Curves.easeOut,
            placeholder: (context, url) => _ShimmerCircle(isDark: isDark),
            errorWidget: (context, url, error) {
              debugPrint('[KnockpostAvatar] ✗ Load failed: $url');
              return Center(child: _fallbackContent());
            },
          ),
        ),
      ),
    );
  }


  Widget _fallbackContent() {
    if (name != null && name!.isNotEmpty) {
      return Text(
        name![0].toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white60 : Colors.black45,
        ),
      );
    }
    return Icon(
      Icons.person,
      size: radius * 1.1,
      color: Colors.grey.shade500,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer circle — subtle pulse while loading
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerCircle extends StatefulWidget {
  final bool isDark;
  const _ShimmerCircle({required this.isDark});

  @override
  State<_ShimmerCircle> createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<_ShimmerCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFE0E0E0);
    final highlightColor = widget.isDark
        ? const Color(0xFF333333)
        : const Color(0xFFF2F2F2);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ColoredBox(
          color: Color.lerp(baseColor, highlightColor, _controller.value)!,
        );
      },
    );
  }
}
