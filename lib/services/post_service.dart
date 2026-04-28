import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
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
        imageUrls = await StorageService.instance.uploadPostMedia(post.id, mediaFiles);
      }

      if (coverFile != null) {
        coverUrl = await StorageService.instance.uploadPostCoverImage(post.id, coverFile);
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
  /// Note: Complex queries (like sorting by duration + date) require composite indexes.
  Stream<List<PostModel>> getFeedPosts({int limit = 20}) {
    return postsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Streams waves (video posts marked as waves) for the Waves Feed.
  Stream<List<PostModel>> getWavesStream({int limit = 30}) {
    return postsCollection
        .where('type', isEqualTo: PostType.waves.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
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
