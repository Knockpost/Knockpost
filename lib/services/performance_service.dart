import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// PerformanceService — Singleton for all performance instrumentation.
///
/// Provides:
///  • Named trace management (start/stop/cancel)
///  • Firestore read/write counters
///  • Active listener/stream registry
///  • Session-level metric aggregation
///
/// This service is purely additive — it does NOT change any app behavior,
/// UI, or UX. It only observes and records.
class PerformanceService {
  PerformanceService._internal();
  static final PerformanceService instance = PerformanceService._internal();

  final FirebasePerformance _perf = FirebasePerformance.instance;

  // ── Active Traces ───────────────────────────────────────────────────────────

  /// Map of currently running traces, keyed by trace name.
  final Map<String, Trace> _activeTraces = {};

  /// Starts a new performance trace with the given [name].
  ///
  /// Optional [attributes] are attached as string key-value pairs for filtering
  /// in the Firebase Console (e.g., `{'screen': 'home', 'source': 'cache'}`).
  ///
  /// If a trace with the same name is already active, it is silently stopped
  /// first to prevent leaks.
  Future<void> startTrace(String name, {Map<String, String>? attributes}) async {
    try {
      // Stop any existing trace with the same name to prevent leaks.
      if (_activeTraces.containsKey(name)) {
        await stopTrace(name);
      }

      final trace = _perf.newTrace(name);
      if (attributes != null) {
        for (final entry in attributes.entries) {
          trace.putAttribute(entry.key, entry.value);
        }
      }
      await trace.start();
      _activeTraces[name] = trace;
    } catch (e) {
      debugPrint('PerformanceService.startTrace($name) error: $e');
    }
  }

  /// Stops a running trace with the given [name] and submits it to Firebase.
  ///
  /// Optional [metrics] are attached as integer counters (e.g.,
  /// `{'postCount': 15, 'cacheHits': 3}`).
  ///
  /// Returns silently if no trace with [name] is active.
  Future<void> stopTrace(String name, {Map<String, int>? metrics}) async {
    try {
      final trace = _activeTraces.remove(name);
      if (trace == null) return;

      if (metrics != null) {
        for (final entry in metrics.entries) {
          trace.setMetric(entry.key, entry.value);
        }
      }
      await trace.stop();
    } catch (e) {
      debugPrint('PerformanceService.stopTrace($name) error: $e');
    }
  }

  /// Cancels a running trace without submitting it.
  /// Useful when the measured operation was abandoned (e.g., user navigated away).
  void cancelTrace(String name) {
    _activeTraces.remove(name);
    // Firebase Performance traces that are not stop()'d are simply discarded.
  }

  /// Returns true if a trace with the given [name] is currently active.
  bool isTraceActive(String name) => _activeTraces.containsKey(name);

  // ── Firestore Read/Write Counters ──────────────────────────────────────────

  int _firestoreReads = 0;
  int _firestoreWrites = 0;
  int _sessionFirestoreReads = 0;
  int _sessionFirestoreWrites = 0;

  // ── Cache Telemetry ──
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _cacheEvictions = 0;
  
  // Specific feed author cache tracking
  int _feedAuthorCacheHits = 0;
  int _feedAuthorCacheMisses = 0;
  int _wavesAuthorCacheHits = 0;
  int _wavesAuthorCacheMisses = 0;
  int _messagingAvatarCacheHits = 0;
  int _messagingAvatarCacheMisses = 0;
  int _sharedPostAuthorCacheHits = 0;
  int _sharedPostAuthorCacheMisses = 0;
  
  // Post Cache tracking
  int _sharedPostCacheHits = 0;
  int _sharedPostCacheMisses = 0;
  int _sharedPostCacheEvictions = 0;
  int _sharedPostRequestDeduplications = 0;

  // ── Feed Pagination Metrics ──
  int _feedPageLoads = 0;
  int _feedPageSizeTotal = 0;
  int _feedPageDurationTotal = 0;
  int _feedRefreshCount = 0;

  // ── Waves Pagination Metrics ──
  int _wavesPageLoads = 0;
  int _wavesPageSizeTotal = 0;
  int _wavesPageDurationTotal = 0;
  int _wavesRefreshCount = 0;

  // ── Optimistic Update Metrics ──
  int _optimisticUpdateSuccess = 0;
  int _optimisticUpdateFailure = 0;
  
  int _wavesOptimisticSuccess = 0;
  int _wavesOptimisticFailure = 0;

  // ── Video Controller Metrics ──
  int _activeVideoControllers = 0;
  int _controllerInitializations = 0;
  int _controllerDisposals = 0;
  int _controllerWindowUpdates = 0;

  int _activeGlimpsControllers = 0;
  int _glimpsControllerInitializations = 0;
  int _glimpsControllerDisposals = 0;
  int _glimpsControllerWindowUpdates = 0;

  // ── Glimps Telemetry ──
  int _glimpsViewDedupHits = 0;
  int _glimpsViewDedupMisses = 0;
  int _glimpsImageCacheHits = 0;
  int _glimpsImageCacheMisses = 0;

  int _glimpsUploadStarted = 0;
  int _glimpsUploadCompleted = 0;
  int _glimpsUploadFailed = 0;
  int _glimpsUploadDurationTotal = 0;

  // ── Messaging Telemetry ──
  int _messagingStreamCacheHits = 0;
  int _messagingStreamCacheMisses = 0;
  int _messagingStreamReuses = 0;
  int _messagingStreamDisposals = 0;
  int _messagingOfflineDuplicateWritesPrevented = 0;
  int _messagingMediaCacheHits = 0;
  int _messagingMediaCacheMisses = 0;
  int _messagingNotificationsSuppressed = 0;
  int _messagingDeleteReadsPrevented = 0;
  int _messagingScalabilityOptimizationsApplied = 0;

  // ── Private Replies Telemetry ──
  int _privateReplyNotificationsCreated = 0;
  int _privateReplyNotificationsOverwrittenPrevented = 0;
  int _privateReplyOwnerUnreadUpdates = 0;
  int _privateReplyUserUnreadUpdates = 0;
  int _privateReplyStreamCacheHits = 0;
  int _privateReplyStreamCacheMisses = 0;
  int _privateReplyStreamDisposals = 0;
  int _privateReplyStreamReuses = 0;

  // ── Notification Telemetry ──
  int _notificationStreamPagesLoaded = 0;
  int _notificationBatchChunksProcessed = 0;
  int _notificationUnreadReadsPrevented = 0;
  int _notificationDeduplicationEvents = 0;
  int _pushProfileReadsPrevented = 0;
  int _notificationSecurityHardeningEvents = 0;
  int _pushPayloadReuseEvents = 0;

  // ── Sharing Phase S3 Telemetry ──
  int _shareSheetPagesLoaded = 0;
  int _shareSheetVirtualizedRows = 0;
  int _shareSheetMemorySavingsEstimate = 0;

  // ── Connection Graph Telemetry ──
  int _connectionGraphReadsPrevented = 0;

  /// Increments the Firestore read counter.
  void incrementReadCount([int count = 1]) {
    _firestoreReads += count;
    _sessionFirestoreReads += count;
  }

  /// Increments the Firestore write counter.
  void incrementWriteCount([int count = 1]) {
    _firestoreWrites += count;
    _sessionFirestoreWrites += count;
  }

  // ── Cache Tracking ──
  void incrementCacheHit() => _cacheHits++;
  void incrementCacheMiss() => _cacheMisses++;
  void incrementCacheEviction() => _cacheEvictions++;
  
  void incrementFeedAuthorCacheHit() => _feedAuthorCacheHits++;
  void incrementFeedAuthorCacheMiss() => _feedAuthorCacheMisses++;
  void incrementWavesAuthorCacheHit() => _wavesAuthorCacheHits++;
  void incrementWavesAuthorCacheMiss() => _wavesAuthorCacheMisses++;
  void incrementMessagingAvatarCacheHit() => _messagingAvatarCacheHits++;
  void incrementMessagingAvatarCacheMiss() => _messagingAvatarCacheMisses++;
  void incrementSharedPostAuthorCacheHit() => _sharedPostAuthorCacheHits++;
  void incrementSharedPostAuthorCacheMiss() => _sharedPostAuthorCacheMisses++;

  void incrementSharedPostCacheHit() => _sharedPostCacheHits++;
  void incrementSharedPostCacheMiss() => _sharedPostCacheMisses++;
  void incrementSharedPostCacheEviction() => _sharedPostCacheEvictions++;
  void incrementSharedPostRequestDeduplication() => _sharedPostRequestDeduplications++;

  // ── Sharing Phase S3 Tracking ──
  void incrementShareSheetPagesLoaded() => _shareSheetPagesLoaded++;
  void incrementShareSheetVirtualizedRows() => _shareSheetVirtualizedRows++;
  void addShareSheetMemorySavingsEstimate(int bytes) => _shareSheetMemorySavingsEstimate += bytes;

  // ── Connection Graph Tracking ──
  void addConnectionGraphReadsPrevented(int count) => _connectionGraphReadsPrevented += count;

  /// Increments optimistic update success
  void incrementOptimisticUpdateSuccess() => _optimisticUpdateSuccess++;

  /// Increments optimistic update failure
  void incrementOptimisticUpdateFailure() => _optimisticUpdateFailure++;

  /// Increments waves optimistic update success
  void incrementWavesOptimisticSuccess() => _wavesOptimisticSuccess++;

  /// Increments waves optimistic update failure
  void incrementWavesOptimisticFailure() => _wavesOptimisticFailure++;

  /// Increments glimps view dedup hit
  void incrementGlimpsViewDedupHit() => _glimpsViewDedupHits++;

  /// Increments glimps view dedup miss
  void incrementGlimpsViewDedupMiss() => _glimpsViewDedupMisses++;

  /// Increments glimps image cache hit
  void incrementGlimpsImageCacheHit() => _glimpsImageCacheHits++;

  /// Increments glimps image cache miss
  void incrementGlimpsImageCacheMiss() => _glimpsImageCacheMisses++;

  /// Tracks a glimpse upload start
  void incrementGlimpsUploadStarted() => _glimpsUploadStarted++;

  /// Tracks a glimpse upload completion and duration
  void logGlimpsUploadCompleted(int durationMs) {
    _glimpsUploadCompleted++;
    _glimpsUploadDurationTotal += durationMs;
  }

  /// Tracks a glimpse upload failure
  void incrementGlimpsUploadFailed() => _glimpsUploadFailed++;

  // ── Messaging Tracking ──
  void incrementMessagingStreamCacheHit() => _messagingStreamCacheHits++;
  void incrementMessagingStreamCacheMiss() => _messagingStreamCacheMisses++;
  void incrementMessagingStreamReuse() => _messagingStreamReuses++;
  void incrementMessagingStreamDisposal() => _messagingStreamDisposals++;
  void incrementMessagingOfflineDuplicateWritesPrevented() => _messagingOfflineDuplicateWritesPrevented++;
  void incrementMessagingMediaCacheHit() => _messagingMediaCacheHits++;
  void incrementMessagingMediaCacheMiss() => _messagingMediaCacheMisses++;
  void incrementMessagingNotificationsSuppressed() {
    _messagingNotificationsSuppressed++;
    incrementMessagingScalabilityOptimizationsApplied();
  }
  void incrementMessagingDeleteReadsPrevented() {
    _messagingDeleteReadsPrevented++;
    incrementMessagingScalabilityOptimizationsApplied();
  }
  void incrementMessagingScalabilityOptimizationsApplied() => _messagingScalabilityOptimizationsApplied++;

  // ── Private Replies Tracking ──
  void incrementPrivateReplyNotificationsCreated() => _privateReplyNotificationsCreated++;
  void incrementPrivateReplyNotificationsOverwrittenPrevented() => _privateReplyNotificationsOverwrittenPrevented++;
  void incrementPrivateReplyOwnerUnreadUpdates() => _privateReplyOwnerUnreadUpdates++;
  void incrementPrivateReplyUserUnreadUpdates() => _privateReplyUserUnreadUpdates++;
  void incrementPrivateReplyStreamCacheHit() => _privateReplyStreamCacheHits++;
  void incrementPrivateReplyStreamCacheMiss() => _privateReplyStreamCacheMisses++;
  void incrementPrivateReplyStreamDisposal() => _privateReplyStreamDisposals++;
  void incrementPrivateReplyStreamReuse() => _privateReplyStreamReuses++;

  // ── Notification Tracking ──
  void incrementNotificationStreamPagesLoaded() => _notificationStreamPagesLoaded++;
  void incrementNotificationBatchChunksProcessed() => _notificationBatchChunksProcessed++;
  void incrementNotificationUnreadReadsPrevented([int count = 1]) => _notificationUnreadReadsPrevented += count;
  void incrementNotificationDeduplicationEvents() => _notificationDeduplicationEvents++;
  void incrementPushProfileReadsPrevented() => _pushProfileReadsPrevented++;
  void incrementNotificationSecurityHardeningEvents() => _notificationSecurityHardeningEvents++;
  void incrementPushPayloadReuseEvents() => _pushPayloadReuseEvents++;

  // ── Video Controller Tracking ──
  /// Updates active video controller count
  void setActiveVideoControllers(int count) => _activeVideoControllers = count;

  /// Increments controller initializations
  void incrementControllerInitializations() => _controllerInitializations++;

  /// Increments controller disposals
  void incrementControllerDisposals() => _controllerDisposals++;

  /// Increments controller window updates
  void incrementControllerWindowUpdates() => _controllerWindowUpdates++;

  // ── Glimps Controller Tracking ──
  /// Updates active glimps controller count
  void setActiveGlimpsControllers(int count) => _activeGlimpsControllers = count;

  /// Increments glimps controller initializations
  void incrementGlimpsControllerInitializations() => _glimpsControllerInitializations++;

  /// Increments glimps controller disposals
  void incrementGlimpsControllerDisposals() => _glimpsControllerDisposals++;

  /// Increments glimps controller window updates
  void incrementGlimpsControllerWindowUpdates() => _glimpsControllerWindowUpdates++;

  /// Logs a waves page load event.
  void logWavesPageLoad({required int size, required int durationMs}) {
    _wavesPageLoads++;
    _wavesPageSizeTotal += size;
    _wavesPageDurationTotal += durationMs;
  }

  /// Increments the waves refresh counter.
  void incrementWavesRefreshCount() => _wavesRefreshCount++;

  /// Returns the total Firestore reads since app launch.
  int get totalReads => _firestoreReads;

  /// Returns the total Firestore writes since app launch.
  int get totalWrites => _firestoreWrites;

  /// Returns the session-level Firestore reads (resets on [resetSessionCounters]).
  int get sessionReads => _sessionFirestoreReads;

  /// Returns the session-level Firestore writes (resets on [resetSessionCounters]).
  int get sessionWrites => _sessionFirestoreWrites;

  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;
  int get cacheEvictions => _cacheEvictions;

  int get feedAuthorCacheHits => _feedAuthorCacheHits;
  int get feedAuthorCacheMisses => _feedAuthorCacheMisses;

  int get feedPageLoads => _feedPageLoads;
  int get feedPageSizeTotal => _feedPageSizeTotal;
  int get feedPageDurationTotal => _feedPageDurationTotal;
  int get feedRefreshCount => _feedRefreshCount;

  /// Records a feed page load.
  void recordFeedPageLoad(int size, int durationMs, {bool isRefresh = false}) {
    _feedPageLoads++;
    _feedPageSizeTotal += size;
    _feedPageDurationTotal += durationMs;
    if (isRefresh) {
      _feedRefreshCount++;
    }
  }

  /// Resets session-level counters. Call when transitioning to a new
  /// logical session (e.g., app returned from background).
  void resetSessionCounters() {
    _sessionFirestoreReads = 0;
    _sessionFirestoreWrites = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _cacheEvictions = 0;
  }

  // ── Active Listener / Stream Registry ──────────────────────────────────────

  /// Registry of active Firestore listeners, keyed by a descriptive name.
  final Map<String, DateTime> _activeListeners = {};

  int _peakListenerCount = 0;

  void trackListener(String name) {
    _activeListeners[name] = DateTime.now();
    if (_activeListeners.length > _peakListenerCount) {
      _peakListenerCount = _activeListeners.length;
    }
  }

  void untrackListener(String name) {
    _activeListeners.remove(name);
  }

  int get activeListenerCount => _activeListeners.length;
  int get peakListenerCount => _peakListenerCount;

  Map<String, DateTime> get activeListeners =>
      Map.unmodifiable(_activeListeners);

  List<String> stalledListeners(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _activeListeners.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
  }

  // ── Debug Snapshot ─────────────────────────────────────────────────────────

  Map<String, dynamic> get debugSnapshot => {
        'firestoreReads': _firestoreReads,
        'firestoreWrites': _firestoreWrites,
        'sessionReads': _sessionFirestoreReads,
        'sessionWrites': _sessionFirestoreWrites,
        'cacheHits': _cacheHits,
        'cacheMisses': _cacheMisses,
        'cacheEvictions': _cacheEvictions,
        'feedAuthorCacheHits': _feedAuthorCacheHits,
        'feedAuthorCacheMisses': _feedAuthorCacheMisses,
        'wavesAuthorCacheHits': _wavesAuthorCacheHits,
        'wavesAuthorCacheMisses': _wavesAuthorCacheMisses,
        'messagingAvatarCacheHits': _messagingAvatarCacheHits,
        'messagingAvatarCacheMisses': _messagingAvatarCacheMisses,
        'sharedPostAuthorCacheHits': _sharedPostAuthorCacheHits,
        'sharedPostAuthorCacheMisses': _sharedPostAuthorCacheMisses,
        'sharedPostCacheHits': _sharedPostCacheHits,
        'sharedPostCacheMisses': _sharedPostCacheMisses,
        'sharedPostCacheEvictions': _sharedPostCacheEvictions,
        'sharedPostRequestDeduplications': _sharedPostRequestDeduplications,
        'optimisticUpdateSuccess': _optimisticUpdateSuccess,
        'optimisticUpdateFailure': _optimisticUpdateFailure,
        'wavesOptimisticSuccess': _wavesOptimisticSuccess,
        'wavesOptimisticFailure': _wavesOptimisticFailure,
        'glimpsViewDedupHits': _glimpsViewDedupHits,
        'glimpsViewDedupMisses': _glimpsViewDedupMisses,
        'glimpsImageCacheHits': _glimpsImageCacheHits,
        'glimpsImageCacheMisses': _glimpsImageCacheMisses,
        'glimpsUploadStarted': _glimpsUploadStarted,
        'glimpsUploadCompleted': _glimpsUploadCompleted,
        'glimpsUploadFailed': _glimpsUploadFailed,
        'glimpsUploadAvgDuration': _glimpsUploadCompleted > 0 ? (_glimpsUploadDurationTotal / _glimpsUploadCompleted).round() : 0,
        'activeVideoControllers': _activeVideoControllers,
        'controllerInitializations': _controllerInitializations,
        'controllerDisposals': _controllerDisposals,
        'controllerWindowUpdates': _controllerWindowUpdates,
        'activeGlimpsControllers': _activeGlimpsControllers,
        'glimpsControllerInitializations': _glimpsControllerInitializations,
        'glimpsControllerDisposals': _glimpsControllerDisposals,
        'glimpsControllerWindowUpdates': _glimpsControllerWindowUpdates,
        'messagingStreamCacheHits': _messagingStreamCacheHits,
        'messagingStreamCacheMisses': _messagingStreamCacheMisses,
        'messagingStreamReuses': _messagingStreamReuses,
        'messagingStreamDisposals': _messagingStreamDisposals,
        'messagingOfflineDuplicateWritesPrevented': _messagingOfflineDuplicateWritesPrevented,
        'messagingNotificationsSuppressed': _messagingNotificationsSuppressed,
        'messagingDeleteReadsPrevented': _messagingDeleteReadsPrevented,
        'messagingScalabilityOptimizationsApplied': _messagingScalabilityOptimizationsApplied,
        'privateReplyNotificationsCreated': _privateReplyNotificationsCreated,
        'privateReplyNotificationsOverwrittenPrevented': _privateReplyNotificationsOverwrittenPrevented,
        'privateReplyOwnerUnreadUpdates': _privateReplyOwnerUnreadUpdates,
        'privateReplyUserUnreadUpdates': _privateReplyUserUnreadUpdates,
        'privateReplyStreamCacheHits': _privateReplyStreamCacheHits,
        'privateReplyStreamCacheMisses': _privateReplyStreamCacheMisses,
        'privateReplyStreamDisposals': _privateReplyStreamDisposals,
        'privateReplyStreamReuses': _privateReplyStreamReuses,
        'notificationStreamPagesLoaded': _notificationStreamPagesLoaded,
        'notificationBatchChunksProcessed': _notificationBatchChunksProcessed,
        'notificationUnreadReadsPrevented': _notificationUnreadReadsPrevented,
        'notificationDeduplicationEvents': _notificationDeduplicationEvents,
        'pushProfileReadsPrevented': _pushProfileReadsPrevented,
        'notificationSecurityHardeningEvents': _notificationSecurityHardeningEvents,
        'pushPayloadReuseEvents': _pushPayloadReuseEvents,
        'feedPageLoads': _feedPageLoads,
        'feedRefreshCount': _feedRefreshCount,
        'wavesPageLoads': _wavesPageLoads,
        'wavesRefreshCount': _wavesRefreshCount,
        'activeListeners': _activeListeners.length,
        'peakListeners': _peakListenerCount,
        'activeTraces': _activeTraces.keys.toList(),
        'listenerNames': _activeListeners.keys.toList(),
      };

  /// Logs the current debug snapshot to the console.
  void printDebugSnapshot() {
    debugPrint('┌─── PerformanceService Snapshot ───');
    debugPrint('│ Firestore reads:    $_firestoreReads (session: $_sessionFirestoreReads)');
    debugPrint('│ Firestore writes:   $_firestoreWrites (session: $_sessionFirestoreWrites)');
    debugPrint('│ Cache Layer:        Hits: $_cacheHits | Misses: $_cacheMisses | Evictions: $_cacheEvictions');
    debugPrint('│ Cache Breakdown:    Feed Authors(Hits: $_feedAuthorCacheHits, Misses: $_feedAuthorCacheMisses) | Waves Authors(Hits: $_wavesAuthorCacheHits, Misses: $_wavesAuthorCacheMisses) | Chat Avatars(Hits: $_messagingAvatarCacheHits, Misses: $_messagingAvatarCacheMisses) | Shared Post Authors(Hits: $_sharedPostAuthorCacheHits, Misses: $_sharedPostAuthorCacheMisses)');
    debugPrint('│ Post Cache:         Hits: $_sharedPostCacheHits | Misses: $_sharedPostCacheMisses | Evictions: $_sharedPostCacheEvictions | Dedupes: $_sharedPostRequestDeduplications');
    debugPrint('│ Glimps Telemetry:   View Dedup Hits: $_glimpsViewDedupHits | View Dedup Misses: $_glimpsViewDedupMisses | Image Cache Hits: $_glimpsImageCacheHits | Image Cache Misses: $_glimpsImageCacheMisses');
    debugPrint('│ Glimps Uploads:     Started: $_glimpsUploadStarted | Completed: $_glimpsUploadCompleted | Failed: $_glimpsUploadFailed | Avg Duration: ${_glimpsUploadCompleted > 0 ? (_glimpsUploadDurationTotal / _glimpsUploadCompleted).round() : 0}ms');
    debugPrint('│ Video Controllers:  Active: $_activeVideoControllers | Init: $_controllerInitializations | Disposals: $_controllerDisposals | Updates: $_controllerWindowUpdates');
    debugPrint('│ Glimps Controllers: Active: $_activeGlimpsControllers | Init: $_glimpsControllerInitializations | Disposals: $_glimpsControllerDisposals | Updates: $_glimpsControllerWindowUpdates');
    debugPrint('│ Feed Performance:   Page Loads: $_feedPageLoads | Refreshes: $_feedRefreshCount | Avg Size: ${_feedPageLoads > 0 ? (_feedPageSizeTotal / _feedPageLoads).toStringAsFixed(1) : 0} | Avg Duration: ${_feedPageLoads > 0 ? (_feedPageDurationTotal / _feedPageLoads).toStringAsFixed(1) : 0}ms');
    debugPrint('│ Waves Performance:  Page Loads: $_wavesPageLoads | Refreshes: $_wavesRefreshCount | Avg Size: ${_wavesPageLoads > 0 ? (_wavesPageSizeTotal / _wavesPageLoads).toStringAsFixed(1) : 0} | Avg Duration: ${_wavesPageLoads > 0 ? (_wavesPageDurationTotal / _wavesPageLoads).toStringAsFixed(1) : 0}ms');
    debugPrint('│ Messaging:          Stream Hits: $_messagingStreamCacheHits | Stream Misses: $_messagingStreamCacheMisses | Reuses: $_messagingStreamReuses | Disposals: $_messagingStreamDisposals');
    debugPrint('│ Messaging Memory:   Avatar Hits: $_messagingAvatarCacheHits | Avatar Misses: $_messagingAvatarCacheMisses | Media Hits: $_messagingMediaCacheHits | Media Misses: $_messagingMediaCacheMisses');
    debugPrint('│ Messaging Polish:   Suppressed Pushes: $_messagingNotificationsSuppressed | Delete Reads Prevented: $_messagingDeleteReadsPrevented | Scalability Ops: $_messagingScalabilityOptimizationsApplied | Offline Dedupes: $_messagingOfflineDuplicateWritesPrevented');
    debugPrint('│ Private Replies:    Created: $_privateReplyNotificationsCreated | Overwrite Prevented: $_privateReplyNotificationsOverwrittenPrevented | Owner Unread: $_privateReplyOwnerUnreadUpdates | User Unread: $_privateReplyUserUnreadUpdates');
    debugPrint('│ Notifications:      Pages Loaded: $_notificationStreamPagesLoaded | Batch Chunks: $_notificationBatchChunksProcessed | Reads Prevented: $_notificationUnreadReadsPrevented | Dedupes: $_notificationDeduplicationEvents');
    debugPrint('│ Push Architecture:  Profile Reads Prevented: $_pushProfileReadsPrevented | Security Hardening: $_notificationSecurityHardeningEvents | Payload Reuse: $_pushPayloadReuseEvents');
    debugPrint('│ Active listeners:   ${_activeListeners.length} (peak: $_peakListenerCount)');
    debugPrint('│ Active traces:      ${_activeTraces.keys.join(', ')}');
    if (_activeListeners.isNotEmpty) {
      debugPrint('│ Listener names:     ${_activeListeners.keys.join(', ')}');
    }
    final stalled = stalledListeners(const Duration(minutes: 10));
    if (stalled.isNotEmpty) {
      debugPrint('│ ⚠ Stalled (>10m):  ${stalled.join(', ')}');
    }
    debugPrint('└───────────────────────────────────');
  }
}
