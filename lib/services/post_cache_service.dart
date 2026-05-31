import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import 'performance_service.dart';

class _PostCacheEntry {
  final PostModel post;
  final DateTime fetchedAt;

  _PostCacheEntry(this.post, this.fetchedAt);
}

/// Centralized Post Cache Layer.
/// Provides an in-memory LRU cache to reduce Firestore reads for shared posts.
class PostCacheService {
  PostCacheService._internal();
  static final PostCacheService instance = PostCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // LRU Cache configuration
  final int _maxSize = 500;
  static const Duration _postTtl = Duration(minutes: 5);

  // LinkedHashMap preserves insertion order, making it perfect for LRU
  final LinkedHashMap<String, _PostCacheEntry> _cache = LinkedHashMap<String, _PostCacheEntry>();

  // Request Deduplication to prevent cache stampedes
  final Map<String, Future<PostModel?>> _inFlightRequests = {};

  /// Fetch a post, utilizing the memory cache if fresh.
  Future<PostModel?> getPost(String postId, {bool forceRefresh = false}) async {
    final now = DateTime.now();

    if (!forceRefresh && _cache.containsKey(postId)) {
      final entry = _cache[postId]!;
      if (now.difference(entry.fetchedAt) < _postTtl) {
        PerformanceService.instance.incrementSharedPostCacheHit();
        
        // Move to end (most recently used)
        _cache.remove(postId);
        _cache[postId] = entry;
        
        return entry.post;
      } else {
        // Expired
        _cache.remove(postId);
      }
    }

    PerformanceService.instance.incrementSharedPostCacheMiss();

    // Deduplicate concurrent requests for the same postId
    if (_inFlightRequests.containsKey(postId)) {
      PerformanceService.instance.incrementSharedPostRequestDeduplication();
      return await _inFlightRequests[postId];
    }

    final fetchFuture = _fetchAndCachePost(postId, now);
    _inFlightRequests[postId] = fetchFuture;
    try {
      return await fetchFuture;
    } finally {
      _inFlightRequests.remove(postId);
    }
  }

  Future<PostModel?> _fetchAndCachePost(String postId, DateTime now) async {
    try {
      // First try cache source (Firestore SDK SQLite cache)
      var doc = await _firestore.collection('posts').doc(postId).get(const GetOptions(source: Source.cache)).catchError((_) => _firestore.collection('posts').doc(postId).get());
      if (!doc.exists) {
        // Fallback to server read
        doc = await _firestore.collection('posts').doc(postId).get();
        PerformanceService.instance.incrementReadCount(); // Only count server reads for billing estimates
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final post = PostModel.fromMap(data, doc.id);
        
        // Add to memory cache
        _cache[postId] = _PostCacheEntry(post, now);
        
        // Evict LRU if size exceeded
        if (_cache.length > _maxSize) {
          _cache.remove(_cache.keys.first); // Removes the least recently used
          PerformanceService.instance.incrementSharedPostCacheEviction();
        }
        
        return post;
      }
    } catch (e) {
      debugPrint("Error fetching post in cache service: $e");
    }
    
    return null;
  }

  /// Invalidates a specific post's cache entry
  void invalidatePost(String postId) {
    _cache.remove(postId);
  }

  /// Clears the entire cache
  void clear() {
    _cache.clear();
  }
}
