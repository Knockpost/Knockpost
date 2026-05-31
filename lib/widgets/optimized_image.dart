import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A production-ready image widget that seamlessly handles C1 Media Optimization.
/// 
/// It accepts both an [optimizedUrl] (from Firestore) and a [rawUrl].
/// If the optimized URL is null (because the backend hasn't finished resizing it yet),
/// it safely falls back to the original raw URL.
class OptimizedImage extends StatelessWidget {
  final String rawUrl;
  final String? optimizedUrl;
  
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final dynamic cacheManager;
  final FilterQuality filterQuality;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const OptimizedImage({
    super.key,
    required this.rawUrl,
    this.optimizedUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.cacheManager,
    this.filterQuality = FilterQuality.low,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final String urlToLoad = (optimizedUrl != null && optimizedUrl!.isNotEmpty) 
        ? optimizedUrl! 
        : rawUrl;

    return CachedNetworkImage(
      imageUrl: urlToLoad,
      fit: fit,
      width: width,
      height: height,
      cacheManager: cacheManager,
      filterQuality: filterQuality,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: placeholder,
      errorWidget: (context, url, error) {
        // Built-in fallback: if the optimized URL fails, try the raw URL
        if (urlToLoad != rawUrl) {
          return CachedNetworkImage(
            imageUrl: rawUrl,
            fit: fit,
            width: width,
            height: height,
            cacheManager: cacheManager,
            filterQuality: filterQuality,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            placeholder: placeholder,
            errorWidget: errorWidget ?? (context, _, __) => const Icon(Icons.broken_image, color: Colors.grey),
          );
        }
        if (errorWidget != null) {
          return errorWidget!(context, url, error);
        }
        return const Icon(Icons.broken_image, color: Colors.grey);
      },
    );
  }
}
