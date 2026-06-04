import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

typedef FeedItem = ({PostModel post, UserModel author});

class FeedCacheService {
  FeedCacheService._internal();
  static final FeedCacheService instance = FeedCacheService._internal();

  List<FeedItem>? _cachedPosts;
  DocumentSnapshot? _lastDoc;
  DateTime? _lastFetchTime;
  DateTime? _lastManualRefreshTime;

  // Cache Time To Live (e.g., 10 minutes)
  static const Duration cacheTtl = Duration(minutes: 10);
  
  // Pull-to-refresh cooling time to prevent spamming
  static const Duration refreshCoolingTime = Duration(seconds: 30);

  bool get hasValidCache {
    if (_cachedPosts == null || _cachedPosts!.isEmpty) return false;
    if (_lastFetchTime == null) return false;
    
    // Check if cache has expired
    if (DateTime.now().difference(_lastFetchTime!) > cacheTtl) {
      return false;
    }
    return true;
  }
  
  bool get canManualRefresh {
    if (_lastManualRefreshTime == null) return true;
    return DateTime.now().difference(_lastManualRefreshTime!) > refreshCoolingTime;
  }

  ({List<FeedItem> posts, DocumentSnapshot? lastDoc})? getCache() {
    if (hasValidCache) {
      return (posts: List.from(_cachedPosts!), lastDoc: _lastDoc);
    }
    return null;
  }

  void saveCache(List<FeedItem> posts, DocumentSnapshot? lastDoc) {
    _cachedPosts = List.from(posts);
    _lastDoc = lastDoc;
    _lastFetchTime = DateTime.now();
  }

  void appendCache(List<FeedItem> newPosts, DocumentSnapshot? newLastDoc) {
    if (_cachedPosts != null) {
      _cachedPosts!.addAll(newPosts);
      _lastDoc = newLastDoc;
    } else {
      saveCache(newPosts, newLastDoc);
    }
  }

  void recordManualRefresh() {
    _lastManualRefreshTime = DateTime.now();
  }

  void clear() {
    _cachedPosts = null;
    _lastDoc = null;
    _lastFetchTime = null;
    // We don't clear _lastManualRefreshTime to keep the cooling down effective even if cache is cleared
  }
}
