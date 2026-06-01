import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knockpost/models/post_model.dart';
import 'package:knockpost/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedCacheService {
  static final FeedCacheService instance = FeedCacheService._();
  FeedCacheService._();

  static const String _feedCacheKey = 'offline_feed_cache';

  /// Saves the top [limit] feed items to SharedPreferences.
  Future<void> saveFeed(List<({PostModel post, UserModel author})> feed, {int limit = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final itemsToCache = feed.take(limit).toList();
      final List<Map<String, dynamic>> serializedFeed = itemsToCache.map((item) {
        final postMap = item.post.toMap();
        final authorMap = item.author.toMap();

        // Convert Timestamps to ISO 8601 Strings for JSON serialization
        if (postMap['createdAt'] is Timestamp) {
          postMap['createdAt'] = (postMap['createdAt'] as Timestamp).toDate().toIso8601String();
        }

        if (authorMap['lastSeen'] is Timestamp) {
          authorMap['lastSeen'] = (authorMap['lastSeen'] as Timestamp).toDate().toIso8601String();
        }
        if (authorMap['acceptedAt'] is Timestamp) {
          authorMap['acceptedAt'] = (authorMap['acceptedAt'] as Timestamp).toDate().toIso8601String();
        }

        return {
          'post_id': item.post.id,
          'author_id': item.author.id,
          'post': postMap,
          'author': authorMap,
        };
      }).toList();

      final jsonString = jsonEncode(serializedFeed);
      await prefs.setString(_feedCacheKey, jsonString);
      debugPrint('FeedCacheService: Cached ${itemsToCache.length} feed items.');
    } catch (e) {
      debugPrint('FeedCacheService.saveFeed error: $e');
    }
  }

  /// Loads the cached feed items from SharedPreferences.
  Future<List<({PostModel post, UserModel author})>> loadFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_feedCacheKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(jsonString);
      final List<({PostModel post, UserModel author})> cachedFeed = [];

      for (final item in decodedList) {
        final map = item as Map<String, dynamic>;
        
        final postMap = map['post'] as Map<String, dynamic>;
        final authorMap = map['author'] as Map<String, dynamic>;

        // Convert ISO 8601 Strings back to Timestamps for fromMap compatibility
        if (postMap['createdAt'] is String) {
          postMap['createdAt'] = Timestamp.fromDate(DateTime.parse(postMap['createdAt']));
        }
        if (authorMap['lastSeen'] is String) {
          authorMap['lastSeen'] = Timestamp.fromDate(DateTime.parse(authorMap['lastSeen']));
        }
        if (authorMap['acceptedAt'] is String) {
          authorMap['acceptedAt'] = Timestamp.fromDate(DateTime.parse(authorMap['acceptedAt']));
        }

        final post = PostModel.fromMap(postMap, map['post_id'] as String);
        final author = UserModel.fromMap(authorMap, map['author_id'] as String);

        cachedFeed.add((post: post, author: author));
      }

      debugPrint('FeedCacheService: Loaded ${cachedFeed.length} feed items from cache.');
      return cachedFeed;
    } catch (e) {
      debugPrint('FeedCacheService.loadFeed error: $e');
      return [];
    }
  }

  /// Clears the cached feed (useful on logout).
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedCacheKey);
  }
}
