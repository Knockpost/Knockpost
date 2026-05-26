import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'post_service.dart';
import 'database_service.dart';

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


  final List<PostModel> _allFetchedWaves = [];
  int _currentIndex = 0;
  static const int _pageSize = 10;

  Future<void> loadInitial() async {
    _waves.clear();
    _authors.clear();
    _seenWaveIds.clear();
    _allFetchedWaves.clear();
    _currentIndex = 0;
    _hasMore = true;
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch a large batch to bypass Firebase's missing composite index limitation.
      // This ensures we get all recent waves and can sort them locally perfectly.
      final fetched = await PostService.instance.getAllWaves(limit: 500);
      _allFetchedWaves.addAll(fetched);
      
      await _loadNextPage();
    } catch (e) {
      debugPrint("WavesFeedManager initial load error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    await _loadNextPage();
    
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> _loadNextPage() async {
    if (_currentIndex >= _allFetchedWaves.length) {
      _hasMore = false;
      return;
    }

    final end = (_currentIndex + _pageSize < _allFetchedWaves.length) 
        ? _currentIndex + _pageSize 
        : _allFetchedWaves.length;
        
    final pageWaves = _allFetchedWaves.sublist(_currentIndex, end);
    _currentIndex = end;

    final Set<String> authorIdsToFetch = {};

    for (var post in pageWaves) {
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
        final data = await DatabaseService.instance.getUserProfile(uid, useCache: true);
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
    
    if (_currentIndex >= _allFetchedWaves.length) {
      _hasMore = false;
    }
  }

  /// Refreshes the feed completely
  Future<void> refresh() async {
    await loadInitial();
  }
}
