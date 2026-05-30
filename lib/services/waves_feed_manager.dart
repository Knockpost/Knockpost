import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'post_service.dart';
import 'user_cache_service.dart';
import 'performance_service.dart';

/// Manages the state, pagination, and deduplication of the Waves feed.
class WavesFeedManager extends ChangeNotifier {
  static final WavesFeedManager instance = WavesFeedManager._internal();
  WavesFeedManager._internal();

  final List<PostModel> _waves = [];
  final Map<String, UserModel> _authors = {};
  
  List<PostModel> get waves => _waves;
  Map<String, UserModel> get authors => _authors;

  final Set<String> _seenWaveIds = {};
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;


  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 10;

  Future<void> loadInitial() async {
    if (_isLoading) return; // Refresh protection

    _waves.clear();
    _authors.clear();
    _seenWaveIds.clear();
    _lastDoc = null;
    _hasMore = true;
    _isLoading = true;
    notifyListeners();

    try {
      final stopWatch = Stopwatch()..start();
      final result = await PostService.instance.getWavesPaginated(limit: _pageSize);
      
      await _processFetchedWaves(result.posts);
      
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length == _pageSize;
      
      stopWatch.stop();
      PerformanceService.instance.logWavesPageLoad(
        size: result.posts.length, 
        durationMs: stopWatch.elapsedMilliseconds,
      );
    } catch (e) {
      debugPrint("WavesFeedManager initial load error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return; // Duplicate request protection
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final stopWatch = Stopwatch()..start();
      final result = await PostService.instance.getWavesPaginated(
        startAfter: _lastDoc,
        limit: _pageSize,
      );
      
      await _processFetchedWaves(result.posts);
      
      _lastDoc = result.lastDoc;
      if (result.posts.isEmpty || result.posts.length < _pageSize) {
        _hasMore = false;
      }
      
      stopWatch.stop();
      PerformanceService.instance.logWavesPageLoad(
        size: result.posts.length, 
        durationMs: stopWatch.elapsedMilliseconds,
      );
    } catch (e) {
      debugPrint("WavesFeedManager loadMore error: $e");
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _processFetchedWaves(List<PostModel> fetchedPosts) async {
    final Set<String> authorIdsToFetch = {};

    for (var post in fetchedPosts) {
      if (!_seenWaveIds.contains(post.id)) {
        _waves.add(post);
        _seenWaveIds.add(post.id);
        if (!_authors.containsKey(post.authorId)) {
          authorIdsToFetch.add(post.authorId);
        }
      }
    }

    if (authorIdsToFetch.isNotEmpty) {
      await Future.wait(authorIdsToFetch.map((uid) async {
        final data = await UserCacheService.instance.getUserProfile(uid, isWavesAuthor: true);
        if (data != null) {
          _authors[uid] = UserModel(
            id: uid,
            displayName: data['displayName'] ?? data['username'] ?? 'User',
            username: data['username'] ?? uid,
            avatarAsset: data['profileImageUrl'],
          );
        }
      }));
    }
  }

  /// Refreshes the feed completely
  Future<void> refresh() async {
    PerformanceService.instance.incrementWavesRefreshCount();
    await loadInitial();
  }
}
