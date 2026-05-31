import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'current_user_service.dart';
import 'database_service.dart';
import 'performance_service.dart';

/// Phase S1: Client-Side View Batching Service
/// 
/// Collects view increments locally and flushes them to Firestore in batches.
/// Survives application crashes by serializing pending views to SharedPreferences.
class ViewBatchService extends WidgetsBindingObserver {
  static final ViewBatchService instance = ViewBatchService._internal();

  ViewBatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Pending views: postId -> authorId
  final Map<String, String> _pendingViews = {};
  
  // Local session cache of posts we've already viewed to prevent redundant queuing
  // (Not persisted to disk; it's fine if this resets on hard crash, the Firestore read will dedup it)
  final Set<String> _sessionViewedPosts = {};
  
  Timer? _flushTimer;
  bool _isFlushing = false;
  
  static const String _prefsKey = 'knockpost_pending_views_batch';

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    
    // Attempt to recover any orphaned views from a previous crash/kill
    await _recoverFromPrefs();

    // Flush every 30 seconds if there are pending views
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush immediately when the app goes into the background or is closing
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      flush();
    }
  }

  /// Recover pending views from SharedPreferences and trigger an immediate flush.
  Future<void> _recoverFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_prefsKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final savedMap = Map<String, String>.from(jsonDecode(savedStr));
        _pendingViews.addAll(savedMap);
        
        // Also seed the deduplication set
        _sessionViewedPosts.addAll(savedMap.keys);
        
        if (_pendingViews.isNotEmpty) {
          debugPrint('Recovered ${_pendingViews.length} pending views from previous session. Flushing...');
          flush();
        }
      }
    } catch (e) {
      debugPrint('Error recovering views from prefs: $e');
    }
  }

  /// Save the current pending views to SharedPreferences for crash safety.
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingViews.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, jsonEncode(_pendingViews));
      }
    } catch (e) {
      debugPrint('Error saving views to prefs: $e');
    }
  }

  /// Records a view for a post. If the threshold is met, it triggers a flush.
  void recordView(String postId, String authorId) {
    final myUid = CurrentUserService.instance.currentUser?.id;
    // Skip if not logged in, or if viewing own post
    if (myUid == null || myUid == authorId) return;

    // Fast memory deduplication
    if (_sessionViewedPosts.contains(postId)) return;
    
    _sessionViewedPosts.add(postId);
    _pendingViews[postId] = authorId;
    
    // Persist to disk synchronously-ish (returns Future but begins immediately)
    _saveToPrefs();

    // Flush automatically if queue gets too large
    if (_pendingViews.length >= 20) {
      flush();
    }
  }

  /// Flushes the pending views to Firestore atomically using a WriteBatch.
  Future<void> flush() async {
    if (_pendingViews.isEmpty || _isFlushing) return;
    _isFlushing = true;

    final batchToProcess = Map<String, String>.from(_pendingViews);
    _pendingViews.clear();
    await _saveToPrefs(); // Clear disk queue immediately

    try {
      final currentUser = CurrentUserService.instance.currentUser;
      if (currentUser == null) return;
      final currentUserId = currentUser.id;

      final batch = _firestore.batch();
      int validViewCount = 0;
      
      // We will aggregate author views: authorId -> numberOfValidViews
      Map<String, int> authorIncrements = {};

      // 1. We must verify if the user already viewed these posts natively (e.g. from a past session)
      // to ensure accurate dedup.
      await Future.wait(batchToProcess.keys.map((postId) async {
        final authorId = batchToProcess[postId]!;
        final viewerRef = _firestore.collection('posts').doc(postId).collection('viewers').doc(currentUserId);
        
        final docSnap = await viewerRef.get();
        if (!docSnap.exists) {
          validViewCount++;
          batch.set(viewerRef, {
            'userId': currentUserId,
            'username': currentUser.username,
            'profileImageUrl': currentUser.avatarAsset,
            'viewedAt': FieldValue.serverTimestamp(),
          });

          batch.update(_firestore.collection('posts').doc(postId), {
            'views': FieldValue.increment(1),
          });

          authorIncrements[authorId] = (authorIncrements[authorId] ?? 0) + 1;
        }
      }));

      // 2. Add author aggregate updates to the batch
      for (final entry in authorIncrements.entries) {
        batch.update(_firestore.collection('users').doc(entry.key), {
          'totalViews': FieldValue.increment(entry.value),
        });
      }

      // 3. Commit the batch
      if (validViewCount > 0) {
        await batch.commit();
        
        // 4. Update Telemetry
        PerformanceService.instance.addBatchedViewsFlushed(validViewCount);
        
        // Writes prevented:
        // Normally, each view is 2 writes (post + user). 
        // We did 1 post write per view, but aggregated the user writes.
        // Old way: (validViewCount * 2)
        // New way: (validViewCount * 1) + authorIncrements.length
        int writesPrevented = (validViewCount * 2) - (validViewCount + authorIncrements.length);
        PerformanceService.instance.addWriteOperationsPrevented(writesPrevented);
        
        // 5. Trigger rank recalculation for affected authors
        for (final authorId in authorIncrements.keys) {
           DatabaseService.instance.recalculateCreatorRank(authorId);
        }
      }
    } catch (e) {
      debugPrint("Error flushing views: $e");
      // Put them back to try again later
      _pendingViews.addAll(batchToProcess);
      _saveToPrefs();
      PerformanceService.instance.incrementViewFlushFailures();
    } finally {
      _isFlushing = false;
    }
  }
}
