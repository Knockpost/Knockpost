import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';
import 'connection_service.dart';
import 'database_service.dart';
import 'current_user_service.dart';

class PostService {
  PostService._internal();
  static final PostService instance = PostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get postsCollection => _firestore.collection('posts');

  /// Helper to bidirectionally filter out posts from blocked users AND private accounts.
  Future<List<PostModel>> filterBlockedAndPrivatePosts(
    List<PostModel> posts,
  ) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return posts;

    // Fetch my profile for my blocked users
    final myDoc = await _firestore.collection('users').doc(myUid).get();
    final myBlockedUsers = myDoc.exists
        ? List<String>.from(myDoc.data()?['blockedUsers'] ?? [])
        : <String>[];

    final Set<String> uniqueAuthorIds = posts.map((p) => p.authorId).toSet();
    uniqueAuthorIds.remove(myUid);

    final Map<String, UserModel> authorMap = {};
    final Map<String, KnockStatus> knockStatusMap = {};

    await Future.wait(
      uniqueAuthorIds.map((uid) async {
        try {
          final data = await _firestore.collection('users').doc(uid).get();
          if (data.exists && data.data() != null) {
            final user = UserModel.fromMap(data.data()!, uid);
            authorMap[uid] = user;

            if (user.accountType == AccountType.normal &&
                user.privacyType == PrivacyType.private) {
              knockStatusMap[uid] = await ConnectionService.instance
                  .getKnockStatus(uid);
            }
          }
        } catch (e) {
          debugPrint('PostService: failed to fetch author $uid: $e');
        }
      }),
    );

    return posts.where((post) {
      if (post.authorId == myUid) return true;
      final author = authorMap[post.authorId];
      if (author == null) return false;

      if (myBlockedUsers.contains(author.id)) return false;
      if (author.blockedUsers.contains(myUid)) return false;

      // Privacy Check
      if (author.accountType == AccountType.normal &&
          author.privacyType == PrivacyType.private) {
        final status = knockStatusMap[author.id];
        if (status != KnockStatus.knocked &&
            status != KnockStatus.mutualKnocked) {
          return false;
        }
      }

      return true;
    }).toList();
  }

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

        // If media files were provided but none uploaded successfully, fail the post
        if (imageUrls.isEmpty) {
          throw Exception(
            'Failed to upload media files. Please check your connection.',
          );
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
              .map((doc) {
                try {
                  return PostModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                } catch (e) {
                  debugPrint('Error parsing feed post ${doc.id}: $e');
                  return null;
                }
              })
              .where((post) =>
                  post != null && (post.duration == PostDuration.lifetime ||
                  post.isInRecentsWindow))
              .cast<PostModel>()
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
      await Future.wait(
        uniqueAuthorIds.map((uid) async {
          try {
            final data = await _firestore.collection('users').doc(uid).get();
            if (data.exists && data.data() != null) {
              authorMap[uid] = UserModel.fromMap(data.data()!, uid);
            }
          } catch (e) {
            debugPrint('PostService: failed to fetch author $uid: $e');
          }
        }),
      );

      // Fetch privacy statuses in parallel for any private users
      final Map<String, KnockStatus> knockStatusMap = {};
      await Future.wait(
        uniqueAuthorIds.map((uid) async {
          final author = authorMap[uid];
          if (author != null &&
              author.accountType == AccountType.normal &&
              author.privacyType == PrivacyType.private) {
            knockStatusMap[uid] = await ConnectionService.instance
                .getKnockStatus(uid);
          }
        }),
      );

      // Map each post to its author, applying bidirectional block filter & privacy check
      final List<({PostModel post, UserModel author})> validPosts = [];
      for (final post in posts) {
        if (post.authorId == currentUserId) {
          if (currentUserModel != null) {
            validPosts.add((post: post, author: currentUserModel));
          }
          continue;
        }

        final author = authorMap[post.authorId];
        if (author == null) continue;

        if (currentUserModel?.blockedUsers.contains(author.id) ?? false) {
          continue;
        }
        if (author.blockedUsers.contains(currentUserId)) {
          continue;
        }

        if (author.accountType == AccountType.normal &&
            author.privacyType == PrivacyType.private) {
          final status = knockStatusMap[author.id];
          if (status != KnockStatus.knocked &&
              status != KnockStatus.mutualKnocked) {
            continue;
          }
        }

        validPosts.add((post: post, author: author));
      }
      return validPosts;
    });
  }

  /// Streams waves (video posts marked as waves) for the Waves Feed.
  Stream<List<PostModel>> getWavesStream({int limit = 30}) {
    return postsCollection
        .where('type', isEqualTo: PostType.waves.name)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs.map((doc) {
            try {
              return PostModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            } catch (e) {
              debugPrint('Error parsing waves post ${doc.id}: $e');
              return null;
            }
          }).where((p) => p != null).cast<PostModel>().toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts.take(limit).toList();
        })
        .asyncMap(filterBlockedAndPrivatePosts);
  }

  /// Paginated fetch for Waves feed
  Future<({List<PostModel> posts, DocumentSnapshot? lastDoc})> getWavesPaginated({
    DocumentSnapshot? startAfter,
    int limit = 10,
  }) async {
    try {
      Query query = postsCollection
          .where('type', isEqualTo: PostType.waves.name)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        return (posts: <PostModel>[], lastDoc: null);
      }

      final fetchedPosts = snapshot.docs.map((doc) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      final validPosts = await filterBlockedAndPrivatePosts(fetchedPosts);
      
      return (posts: validPosts, lastDoc: snapshot.docs.last);
    } catch (e) {
      debugPrint("Error fetching waves paginated: $e");
      return (posts: <PostModel>[], lastDoc: null);
    }
  }

  /// Fetches all waves up to a limit and sorts them client-side.
  /// This is used to bypass the need for a Firebase Composite Index while still
  /// maintaining perfect chronological order for the feed.
  Future<List<PostModel>> getAllWaves({int limit = 500}) async {
    try {
      final snapshot = await postsCollection
          .where('type', isEqualTo: PostType.waves.name)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final fetchedPosts = snapshot.docs.map((doc) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      final validPosts = await filterBlockedAndPrivatePosts(fetchedPosts);
      
      // Sort client-side to ensure newest waves are first
      validPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return validPosts;
    } catch (e) {
      debugPrint("Error in getAllWaves: $e");
      return [];
    }
  }

  /// Streams active glimpses (stories) for the GlimpsStrip.
  /// Filters out expired glimpses locally to avoid needing a complex composite index.
  Stream<List<PostModel>> getGlimpsesStream({int limit = 30}) {
    return postsCollection
        .where('type', isEqualTo: PostType.glimps.name)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) {
                try {
                  return PostModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                } catch (e) {
                  debugPrint('Error parsing glimpse ${doc.id}: $e');
                  return null;
                }
              })
              .where((post) => post != null && post.isInRecentsWindow)
              .cast<PostModel>()
              .toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts.take(limit).toList();
        })
        .asyncMap(filterBlockedAndPrivatePosts);
  }

  /// Streams a specific user's posts.
  Stream<List<PostModel>> getUserPosts(String userId) {
    return postsCollection.where('authorId', isEqualTo: userId).snapshots().map(
      (snapshot) {
        final posts = snapshot.docs.map((doc) {
          return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts;
      },
    );
  }

  /// Deletes a post from Firestore.
  Future<void> deletePost(String postId) async {
    try {
      await postsCollection.doc(postId).delete();
    } catch (e) {
      debugPrint("Error deleting post: $e");
    }
  }

  /// Increments the view count for a post and the total views for its author.
  /// Strictly allows only 1 view per account (no duplicates).
  /// Does NOT update viewedAt on repeat views to avoid unnecessary stream churn.
  Future<void> incrementViewCount(String postId, String authorId) async {
    try {
      final currentUser = CurrentUserService.instance.currentUser;
      final currentUserId = currentUser?.id;

      // Skip tracking if anonymous or if it's the author's own post
      if (currentUserId != null && currentUserId != authorId) {
        final viewerRef = postsCollection
            .doc(postId)
            .collection('viewers')
            .doc(currentUserId);
        final docSnap = await viewerRef.get();

        // Only count if this user has NEVER viewed this post before
        if (!docSnap.exists) {
          await viewerRef.set({
            'userId': currentUserId,
            'username': currentUser!.username,
            'profileImageUrl': currentUser.avatarAsset,
            'viewedAt': FieldValue.serverTimestamp(),
          });

          await postsCollection.doc(postId).update({
            'views': FieldValue.increment(1),
          });

          await _firestore.collection('users').doc(authorId).update({
            'totalViews': FieldValue.increment(1),
          });

          DatabaseService.instance.recalculateCreatorRank(authorId);
        }
        // No else — do NOT update viewedAt on repeat views.
        // Updating viewedAt causes the orderBy('viewedAt') stream to
        // re-emit the document at a new position, leading to visual
        // duplicates in the viewers list.
      }
    } catch (e) {
      debugPrint("Error incrementing view count: $e");
    }
  }

  /// Streams the list of viewers for a specific post.
  /// Deduplicates by userId to prevent any duplicate entries from appearing
  /// (e.g. from stream re-fires or intermediate Firestore snapshot states).
  Stream<List<Map<String, dynamic>>> getPostViewers(String postId) {
    return postsCollection
        .doc(postId)
        .collection('viewers')
        .snapshots()
        .map((snapshot) {
          final seen = <String>{};
          final viewers = <Map<String, dynamic>>[];
          
          final sortedDocs = snapshot.docs.toList()
            ..sort((a, b) {
              final aTs = a.data()['viewedAt'] as Timestamp?;
              final bTs = b.data()['viewedAt'] as Timestamp?;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return bTs.compareTo(aTs);
            });

          for (final doc in sortedDocs) {
            final data = doc.data();
            final userId = data['userId'] as String? ?? doc.id;
            if (seen.add(userId)) {
              viewers.add(data);
            }
          }
          return viewers;
        });
  }
}
