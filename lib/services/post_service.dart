import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class PostService {
  PostService._internal();
  static final PostService instance = PostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get postsCollection => _firestore.collection('posts');

  /// Creates a new post in Firestore and uploads media to Storage.
  Future<void> createPost({
    required PostModel post,
    required List<File> mediaFiles,
    File? coverFile,
  }) async {
    try {
      List<String> imageUrls = [];
      String? coverUrl;

      if (mediaFiles.isNotEmpty) {
        for (var file in mediaFiles) {
          final url = await StorageService.instance.uploadPostMedia(
            userId: post.authorId,
            postId: post.id,
            file: file,
          );
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      if (coverFile != null) {
        coverUrl = await StorageService.instance.uploadPostCoverImage(
          userId: post.authorId,
          postId: post.id,
          file: coverFile,
        );
      }

      final updatedPost = post.copyWith(
        imagePaths: imageUrls,
        coverImagePath: coverUrl,
      );

      await postsCollection.doc(post.id).set(updatedPost.toMap());
    } catch (e) {
      debugPrint("Error creating post: $e");
      rethrow;
    }
  }

  /// Streams posts for the home feed, ordered by newest first.
  /// Filters out expired h24/h36 posts client-side (lifetime posts always show).
  Stream<List<PostModel>> getFeedPosts({int limit = 20}) {
    return postsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((post) =>
              post.duration == PostDuration.lifetime || post.isInRecentsWindow)
          .toList();
    });
  }

  /// Streams feed posts along with their resolved author [UserModel].
  /// Author profiles are batch-fetched from Firestore whenever the post list changes.
  /// Returns a list of (PostModel, UserModel) records.
  Stream<List<({PostModel post, UserModel author})>> getFeedPostsWithAuthors({
    int limit = 20,
    required String currentUserId,
    required UserModel? currentUserModel,
  }) {
    return getFeedPosts(limit: limit).asyncMap((posts) async {
      // Collect unique author IDs (excluding current user — we already have their data)
      final Set<String> uniqueAuthorIds = {};
      for (final p in posts) {
        if (p.authorId != currentUserId) {
          uniqueAuthorIds.add(p.authorId);
        }
      }

      // Batch-fetch all author profiles in parallel
      final Map<String, UserModel> authorMap = {};
      await Future.wait(uniqueAuthorIds.map((uid) async {
        try {
          final data = await _firestore.collection('users').doc(uid).get();
          if (data.exists && data.data() != null) {
            authorMap[uid] = UserModel.fromMap(data.data()!, uid);
          }
        } catch (e) {
          debugPrint('PostService: failed to fetch author $uid: $e');
        }
      }));

      // Map each post to its author
      return posts.map((post) {
        UserModel author;
        if (post.authorId == currentUserId && currentUserModel != null) {
          author = currentUserModel;
        } else {
          author = authorMap[post.authorId] ??
              UserModel(
                id: post.authorId,
                displayName: 'Unknown',
                username: 'unknown',
              );
        }
        return (post: post, author: author);
      }).toList();
    });
  }

  /// Streams waves (video posts marked as waves) for the Waves Feed.
  Stream<List<PostModel>> getWavesStream({int limit = 30}) {
    return postsCollection
        .where('type', isEqualTo: PostType.waves.name)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts.take(limit).toList();
    });
  }

  /// Streams active glimpses (stories) for the GlimpsStrip.
  /// Filters out expired glimpses locally to avoid needing a complex composite index.
  Stream<List<PostModel>> getGlimpsesStream({int limit = 30}) {
    return postsCollection
        .where('type', isEqualTo: PostType.glimps.name)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).where((post) => post.isInRecentsWindow).toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts.take(limit).toList();
    });
  }

  /// Streams a specific user's posts.
  Stream<List<PostModel>> getUserPosts(String userId) {
    return postsCollection
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  /// Deletes a post from Firestore.
  Future<void> deletePost(String postId) async {
    try {
      await postsCollection.doc(postId).delete();
    } catch (e) {
      debugPrint("Error deleting post: $e");
    }
  }
}
