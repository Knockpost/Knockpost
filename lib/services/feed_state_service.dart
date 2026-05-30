import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'like_service.dart';
import 'post_service.dart';
import 'performance_service.dart';

class PostState {
  final int likes;
  final int views;
  final String? userReaction;
  final List<String> ownerReactions;

  const PostState({
    required this.likes,
    required this.views,
    this.userReaction,
    this.ownerReactions = const [],
  });

  PostState copyWith({
    int? likes,
    int? views,
    String? userReaction,
    // Note: userReaction can be null, so we need a way to pass "clear this"
    bool clearUserReaction = false,
    List<String>? ownerReactions,
  }) {
    return PostState(
      likes: likes ?? this.likes,
      views: views ?? this.views,
      userReaction: clearUserReaction ? null : (userReaction ?? this.userReaction),
      ownerReactions: ownerReactions ?? this.ownerReactions,
    );
  }
}

class FeedStateService {
  FeedStateService._privateConstructor();
  static final FeedStateService instance = FeedStateService._privateConstructor();

  final Map<String, ValueNotifier<PostState>> _stateMap = {};

  /// Retrieves or initializes a ValueNotifier for a post.
  ValueNotifier<PostState> getNotifier(String postId, {int initialLikes = 0, int initialViews = 0}) {
    if (!_stateMap.containsKey(postId)) {
      _stateMap[postId] = ValueNotifier<PostState>(
        PostState(likes: initialLikes, views: initialViews),
      );
    }
    return _stateMap[postId]!;
  }

  /// One-time fetch for user reaction (current user).
  Future<void> fetchUserReaction(String postId, String userId) async {
    if (userId.isEmpty || postId.isEmpty) return;
    try {
      final reaction = await LikeService.instance.getUserReactionFuture(postId, userId);
      if (reaction != null && _stateMap.containsKey(postId)) {
        final notifier = _stateMap[postId]!;
        notifier.value = notifier.value.copyWith(userReaction: reaction);
      }
    } catch (e) {
      debugPrint('FeedStateService: failed to fetch user reaction: $e');
    }
  }

  /// One-time fetch for owner reactions summary.
  Future<void> fetchOwnerReactions(String postId) async {
    if (postId.isEmpty) return;
    try {
      final reactions = await LikeService.instance.getPostReactionsFuture(postId);
      final emojisToShow = <String>[];
      final uniqueEmojis = <String>{};

      for (final reactor in reactions) {
        final emoji = reactor['reaction'] as String? ?? '❤';
        if (uniqueEmojis.add(emoji)) {
          emojisToShow.add(emoji);
          if (emojisToShow.length == 3) break;
        }
      }

      if (_stateMap.containsKey(postId)) {
        final notifier = _stateMap[postId]!;
        notifier.value = notifier.value.copyWith(ownerReactions: emojisToShow);
      }
    } catch (e) {
      debugPrint('FeedStateService: failed to fetch owner reactions: $e');
    }
  }

  /// Increment view count optimistically.
  void incrementView(String postId, String userId) {
    if (postId.isEmpty || userId.isEmpty) return;
    
    final notifier = getNotifier(postId);
    notifier.value = notifier.value.copyWith(views: notifier.value.views + 1);
    
    // Background write
    PostService.instance.incrementViewCount(postId, userId).catchError((e) {
      debugPrint('FeedStateService: Failed to increment view in Firestore: $e');
      // Views are low stakes, rollback is less critical, but we log it.
      PerformanceService.instance.incrementOptimisticUpdateFailure();
    });
  }

  /// Toggle like optimistically with rollback safety.
  void toggleLike({
    required String postId,
    required String userId,
    required String postAuthorId,
    required bool isLiking,
    String reactionType = '❤',
    bool isWaves = false,
  }) {
    if (postId.isEmpty || userId.isEmpty) return;

    final notifier = getNotifier(postId);
    final previousState = notifier.value;

    // Optimistic Update
    final newLikes = isLiking ? previousState.likes + 1 : previousState.likes - 1;
    notifier.value = previousState.copyWith(
      likes: newLikes < 0 ? 0 : newLikes,
      userReaction: isLiking ? reactionType : null,
      clearUserReaction: !isLiking,
    );

    // Background write
    LikeService.instance.toggleLike(
      postId: postId,
      userId: userId,
      postAuthorId: postAuthorId,
      isLiking: isLiking,
      reactionType: reactionType,
    ).then((_) {
      if (isWaves) {
        PerformanceService.instance.incrementWavesOptimisticSuccess();
      } else {
        PerformanceService.instance.incrementOptimisticUpdateSuccess();
      }
    }).catchError((e) {
      debugPrint('FeedStateService: Failed to toggle like in Firestore: $e');
      // Rollback
      notifier.value = previousState;
      if (isWaves) {
        PerformanceService.instance.incrementWavesOptimisticFailure();
      } else {
        PerformanceService.instance.incrementOptimisticUpdateFailure();
      }
    });
  }
}
