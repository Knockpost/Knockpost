import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'performance_service.dart';

/// Intercepts HTTP requests made by the CacheManager to record cache misses.
class InstrumentedHttpFileService extends HttpFileService {
  InstrumentedHttpFileService() : super(httpClient: http.Client());

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) {
    // If CacheManager delegates to the FileService, it means it was a cache miss.
    PerformanceService.instance.incrementCacheMiss();
    if (url.contains('chats%2F')) {
      PerformanceService.instance.incrementMessagingMediaCacheMiss();
    }
    return super.get(url, headers: headers);
  }
}

/// Centralized Image Cache Manager for Knockpost.
/// Enforces limits on memory/disk bloat and provides metrics integration.
class KnockpostImageCacheManager extends CacheManager {
  static const key = 'knockpostImageCache';

  static final KnockpostImageCacheManager instance = KnockpostImageCacheManager._();

  KnockpostImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 1000,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: InstrumentedHttpFileService(),
          ),
        );

  @override
  Stream<FileResponse> getFileStream(String url, {String? key, Map<String, String>? headers, bool withProgress = false}) {
    // Overriding getFileStream to catch hits.
    // If the stream immediately returns a FileInfo object without reaching out to the FileService,
    // it's a hit. A miss will first yield a DownloadProgress and then fetch.
    return super.getFileStream(url, key: key, headers: headers, withProgress: withProgress).map((response) {
      if (response is FileInfo) {
        // We only consider it a hit if it's returning the final file.
        // The miss is tracked inside InstrumentedHttpFileService.get().
        // To precisely track a pure hit (served from cache, no network), we can check response.source.
        // But since we can't easily access the source directly from FileInfo without custom fields,
        // we'll rely on the get() intercept for misses, and we could increment hits here,
        // but flutter_cache_manager's default behavior returns FileInfo even after a fresh download.
        // It's safer to just log hits manually where we can, or just rely on misses for now.
        // Actually, flutter_cache_manager's FileInfo has a source property (FileSource.Cache vs FileSource.Online)
        // Wait, FileInfo has `FileSource source`.
        if (response.source == FileSource.Cache) {
          PerformanceService.instance.incrementCacheHit();
          if (url.contains('chats%2F')) {
            PerformanceService.instance.incrementMessagingMediaCacheHit();
          }
        }
      }
      return response;
    });
  }
}
