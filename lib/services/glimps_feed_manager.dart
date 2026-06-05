import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'post_service.dart';
import 'user_cache_service.dart';
import 'video_cache_manager.dart';
import 'image_cache_manager.dart';

/// Manages the state and pagination of the Glimps feed, replacing the global Stream.
class GlimpsFeedManager extends ChangeNotifier {
  static final GlimpsFeedManager instance = GlimpsFeedManager._internal();
  GlimpsFeedManager._internal();

  final List<PostModel> _glimpses = [];
  final Map<String, UserModel> _authors = {};
  
  List<PostModel> get glimpses => _glimpses;
  Map<String, UserModel> get authors => _authors;

  final Set<String> _seenGlimpseIds = {};
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 50; // Larger page size since glimpses are ephemeral

  Future<void> loadInitial() async {
    if (_isLoading) return;

    _glimpses.clear();
    _authors.clear();
    _seenGlimpseIds.clear();
    _lastDoc = null;
    _hasMore = true;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await PostService.instance.getGlimpsesPaginated(limit: _pageSize);
      
      _processFetchedGlimpses(result.posts);
      
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length == _pageSize;
      
    } catch (e) {
      debugPrint("GlimpsFeedManager initial load error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
      _preloadTopGlimpses();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final result = await PostService.instance.getGlimpsesPaginated(
        startAfter: _lastDoc,
        limit: _pageSize,
      );
      
      _processFetchedGlimpses(result.posts);
      
      _lastDoc = result.lastDoc;
      if (result.posts.isEmpty || result.posts.length < _pageSize) {
        _hasMore = false;
      }
      
    } catch (e) {
      debugPrint("GlimpsFeedManager loadMore error: $e");
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _processFetchedGlimpses(List<PostModel> fetchedPosts) {
    final Set<String> authorIdsToFetch = {};

    for (var post in fetchedPosts) {
      if (!_seenGlimpseIds.contains(post.id)) {
        _glimpses.add(post);
        _seenGlimpseIds.add(post.id);
        if (!_authors.containsKey(post.authorId)) {
          authorIdsToFetch.add(post.authorId);
        }
      }
    }

    if (authorIdsToFetch.isNotEmpty) {
      // Non-blocking background resolution of authors
      Future.wait(authorIdsToFetch.map((uid) async {
        final data = await UserCacheService.instance.getUserProfile(uid);
        if (data != null) {
          _authors[uid] = UserModel(
            id: uid,
            displayName: data['displayName'] ?? data['username'] ?? 'User',
            username: data['username'] ?? uid,
            avatarAsset: data['profileImageUrl'],
          );
          notifyListeners();
        }
      }));
    }
  }

  void _preloadTopGlimpses() {
    final Map<String, PostModel> topGlimpses = {};
    for (var g in _glimpses) {
      if (!topGlimpses.containsKey(g.authorId)) {
        topGlimpses[g.authorId] = g;
      }
      if (topGlimpses.length >= 5) break;
    }

    for (var g in topGlimpses.values) {
      if (g.imagePaths.isNotEmpty) {
        final path = g.imagePaths.first;
        final pathLower = path.toLowerCase();
        final isVideo = pathLower.contains('.mp4') || pathLower.contains('.mov') || pathLower.contains('.mkv') || pathLower.contains('.webm');
        if (isVideo) {
          KnockpostVideoCacheManager.instance.downloadFile(path);
        } else {
          KnockpostImageCacheManager.instance.downloadFile(path);
        }
      }
    }
  }

  /// Adds a glimpse optimistically to the local state so the user sees it immediately.
  void addGlimpseOptimistically(PostModel glimpse, UserModel author) {
    // Insert at the beginning of the feed.
    _glimpses.insert(0, glimpse);
    _authors[author.id] = author;
    _seenGlimpseIds.add(glimpse.id);
    notifyListeners();
  }

  /// Removes a glimpse from the local state (e.g. if background upload fails).
  void removeGlimpse(String glimpseId) {
    _glimpses.removeWhere((g) => g.id == glimpseId);
    _seenGlimpseIds.remove(glimpseId);
    notifyListeners();
  }
}
