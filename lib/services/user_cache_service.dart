import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'performance_service.dart';

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime fetchedAt;

  _CacheEntry(this.data, this.fetchedAt);
}

/// Centralized User Profile Cache Layer.
/// Provides an in-memory LRU cache to reduce Firestore reads.
class UserCacheService {
  UserCacheService._internal();
  static final UserCacheService instance = UserCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // LRU Cache configuration
  final int _maxSize = 500;
  static const Duration _otherUserTtl = Duration(minutes: 5);
  static const Duration _currentUserTtl = Duration(seconds: 30);

  // LinkedHashMap preserves insertion order, making it perfect for LRU
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap<String, _CacheEntry>();

  // Request Deduplication to prevent cache stampedes
  final Map<String, Future<Map<String, dynamic>?>> _inFlightRequests = {};

  /// Synchronously fetch a user profile from the memory cache if it's fresh.
  /// Returns null if not cached or expired.
  Map<String, dynamic>? getCachedUserProfile(String uid) {
    final now = DateTime.now();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final ttl = (uid == myUid) ? _currentUserTtl : _otherUserTtl;

    if (_cache.containsKey(uid)) {
      final entry = _cache[uid]!;
      if (now.difference(entry.fetchedAt) < ttl) {
        // Move to end (most recently used)
        _cache.remove(uid);
        _cache[uid] = entry;
        return entry.data;
      } else {
        _cache.remove(uid);
      }
    }
    return null;
  }

  /// Fetch a user profile, utilizing the memory cache if fresh.
  Future<Map<String, dynamic>?> getUserProfile(String uid, {bool forceRefresh = false, bool isFeedAuthor = false, bool isWavesAuthor = false, bool isMessagingAuthor = false, bool isSharedPostAuthor = false}) async {
    final now = DateTime.now();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final ttl = (uid == myUid) ? _currentUserTtl : _otherUserTtl;

    if (!forceRefresh && _cache.containsKey(uid)) {
      final entry = _cache[uid]!;
      if (now.difference(entry.fetchedAt) < ttl) {
        PerformanceService.instance.incrementCacheHit();
        if (isFeedAuthor) PerformanceService.instance.incrementFeedAuthorCacheHit();
        if (isWavesAuthor) PerformanceService.instance.incrementWavesAuthorCacheHit();
        if (isMessagingAuthor) PerformanceService.instance.incrementMessagingAvatarCacheHit();
        if (isSharedPostAuthor) PerformanceService.instance.incrementSharedPostAuthorCacheHit();
        
        // Move to end (most recently used)
        _cache.remove(uid);
        _cache[uid] = entry;
        
        return entry.data;
      } else {
        // Expired
        _cache.remove(uid);
      }
    }

    PerformanceService.instance.incrementCacheMiss();
    if (isFeedAuthor) PerformanceService.instance.incrementFeedAuthorCacheMiss();
    if (isWavesAuthor) PerformanceService.instance.incrementWavesAuthorCacheMiss();
    if (isMessagingAuthor) PerformanceService.instance.incrementMessagingAvatarCacheMiss();
    if (isSharedPostAuthor) PerformanceService.instance.incrementSharedPostAuthorCacheMiss();

    // Deduplicate concurrent requests for the same UID
    if (_inFlightRequests.containsKey(uid)) {
      return await _inFlightRequests[uid];
    }

    final fetchFuture = _fetchAndCacheProfile(uid, now);
    _inFlightRequests[uid] = fetchFuture;
    try {
      return await fetchFuture;
    } finally {
      _inFlightRequests.remove(uid);
    }
  }

  Future<Map<String, dynamic>?> _fetchAndCacheProfile(String uid, DateTime now) async {
    try {
      // First try cache source (Firestore SDK SQLite cache)
      var doc = await _firestore.collection('users').doc(uid).get(const GetOptions(source: Source.cache)).catchError((_) => _firestore.collection('users').doc(uid).get());
      if (!doc.exists) {
        // Fallback to server read
        doc = await _firestore.collection('users').doc(uid).get();
        PerformanceService.instance.incrementReadCount(); // Only count server reads for billing estimates
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Add to memory cache
        _cache[uid] = _CacheEntry(data, now);
        
        // Evict LRU if size exceeded
        if (_cache.length > _maxSize) {
          _cache.remove(_cache.keys.first); // Removes the least recently used
          PerformanceService.instance.incrementCacheEviction();
        }
        
        return data;
      }
    } catch (e) {
      debugPrint("Error fetching user profile in cache service: $e");
    }
    
    return null;
  }

  /// Invalidates a specific user's cache entry (e.g. after an edit)
  void invalidateUser(String uid) {
    _cache.remove(uid);
  }

  /// Clears the entire cache (e.g. on logout)
  void clear() {
    _cache.clear();
  }
}
