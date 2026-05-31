import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Centralized Video Cache Manager for Knockpost.
/// Enforces limits on memory/disk bloat specifically for video files.
/// This enables instant, zero-delay video playback from disk.
class KnockpostVideoCacheManager extends CacheManager {
  static const key = 'knockpostVideoCache';

  static final KnockpostVideoCacheManager instance = KnockpostVideoCacheManager._();

  KnockpostVideoCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 200, // Videos are larger, so we keep fewer than images
            repo: JsonCacheInfoRepository(databaseName: key),
          ),
        );
}
