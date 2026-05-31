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

  // ── Cache Counters ──
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _cacheEvictions = 0;

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

  // ── Feed Author Cache Metrics ──
  int _feedAuthorCacheHits = 0;
  int _feedAuthorCacheMisses = 0;

  // ── Waves Author Cache Metrics ──
  int _wavesAuthorCacheHits = 0;
  int _wavesAuthorCacheMisses = 0;

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

  /// Increments the Firestore read counter.
  ///
  /// Call this from any service that performs a `.get()` or receives an initial
  /// `.snapshots()` emission. Pass [count] to increment by more than 1
  /// (e.g., for batch reads).
  void incrementReadCount([int count = 1]) {
    _firestoreReads += count;
    _sessionFirestoreReads += count;
  }

  /// Increments the Firestore write counter.
  ///
  /// Call this from any service that performs a `.set()`, `.update()`,
  /// `.delete()`, or batch write. Pass [count] for batch operations.
  void incrementWriteCount([int count = 1]) {
    _firestoreWrites += count;
    _sessionFirestoreWrites += count;
  }

  /// Increments the cache hit counter.
  void incrementCacheHit() => _cacheHits++;

  /// Increments the cache miss counter.
  void incrementCacheMiss() => _cacheMisses++;

  /// Increments the cache eviction counter.
  void incrementCacheEviction() => _cacheEvictions++;

  /// Increments feed author cache hit counter
  void incrementFeedAuthorCacheHit() => _feedAuthorCacheHits++;

  /// Increments feed author cache miss counter
  void incrementFeedAuthorCacheMiss() => _feedAuthorCacheMisses++;

  /// Increments waves author cache hit counter
  void incrementWavesAuthorCacheHit() => _wavesAuthorCacheHits++;

  /// Increments waves author cache miss counter
  void incrementWavesAuthorCacheMiss() => _wavesAuthorCacheMisses++;

  /// Increments optimistic update success
  void incrementOptimisticUpdateSuccess() => _optimisticUpdateSuccess++;

  /// Increments optimistic update failure
  void incrementOptimisticUpdateFailure() => _optimisticUpdateFailure++;

  /// Increments waves optimistic update success
  void incrementWavesOptimisticSuccess() => _wavesOptimisticSuccess++;

  /// Increments waves optimistic update failure
  void incrementWavesOptimisticFailure() => _wavesOptimisticFailure++;

  /// Updates active video controller count
  void setActiveVideoControllers(int count) => _activeVideoControllers = count;

  /// Increments controller initializations
  void incrementControllerInitializations() => _controllerInitializations++;

  /// Increments controller disposals
  void incrementControllerDisposals() => _controllerDisposals++;

  /// Increments controller window updates
  void incrementControllerWindowUpdates() => _controllerWindowUpdates++;

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
  /// Value is the timestamp when the listener was registered.
  final Map<String, DateTime> _activeListeners = {};

  /// Peak concurrent listener count observed during this session.
  int _peakListenerCount = 0;

  /// Registers a named listener in the active listener registry.
  ///
  /// Call this whenever a `.snapshots().listen()` or `StreamBuilder` subscribes
  /// to a Firestore stream. Use a descriptive name like
  /// `'feed_posts'`, `'chat_messages_{chatId}'`, or `'knock_{userId}'`.
  void trackListener(String name) {
    _activeListeners[name] = DateTime.now();
    if (_activeListeners.length > _peakListenerCount) {
      _peakListenerCount = _activeListeners.length;
    }
  }

  /// Unregisters a named listener from the active listener registry.
  ///
  /// Call this in `dispose()` or when a stream subscription is cancelled.
  void untrackListener(String name) {
    _activeListeners.remove(name);
  }

  /// Returns the number of currently active Firestore listeners.
  int get activeListenerCount => _activeListeners.length;

  /// Returns the peak concurrent listener count observed this session.
  int get peakListenerCount => _peakListenerCount;

  /// Returns an unmodifiable snapshot of all active listeners with their
  /// start times, useful for debugging.
  Map<String, DateTime> get activeListeners =>
      Map.unmodifiable(_activeListeners);

  /// Returns a list of listener names that have been active longer than
  /// [duration], useful for detecting leaked listeners.
  List<String> stalledListeners(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _activeListeners.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
  }

  // ── Debug Snapshot ─────────────────────────────────────────────────────────

  /// Returns a human-readable snapshot of all performance metrics.
  /// Useful for debug overlays and logging.
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
        'optimisticUpdateSuccess': _optimisticUpdateSuccess,
        'optimisticUpdateFailure': _optimisticUpdateFailure,
        'wavesOptimisticSuccess': _wavesOptimisticSuccess,
        'wavesOptimisticFailure': _wavesOptimisticFailure,
        'activeVideoControllers': _activeVideoControllers,
        'controllerInitializations': _controllerInitializations,
        'controllerDisposals': _controllerDisposals,
        'controllerWindowUpdates': _controllerWindowUpdates,
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
  /// Call this periodically or on screen transitions for visibility.
  void printDebugSnapshot() {
    debugPrint('┌─── PerformanceService Snapshot ───');
    debugPrint('│ Firestore reads:    $_firestoreReads (session: $_sessionFirestoreReads)');
    debugPrint('│ Firestore writes:   $_firestoreWrites (session: $_sessionFirestoreWrites)');
    debugPrint('│ Cache Profile:      Hits: $_cacheHits | Misses: $_cacheMisses | Evictions: $_cacheEvictions');
    debugPrint('│ Feed Author Cache:  Hits: $_feedAuthorCacheHits | Misses: $_feedAuthorCacheMisses');
    debugPrint('│ Waves Author Cache: Hits: $_wavesAuthorCacheHits | Misses: $_wavesAuthorCacheMisses');
    debugPrint('│ Optimistic Updates: Success: $_optimisticUpdateSuccess | Failures: $_optimisticUpdateFailure');
    debugPrint('│ Waves Optimistic:   Success: $_wavesOptimisticSuccess | Failures: $_wavesOptimisticFailure');
    debugPrint('│ Video Controllers:  Active: $_activeVideoControllers | Init: $_controllerInitializations | Disposals: $_controllerDisposals | Updates: $_controllerWindowUpdates');
    debugPrint('│ Feed Performance:   Page Loads: $_feedPageLoads | Refreshes: $_feedRefreshCount | Avg Size: ${_feedPageLoads > 0 ? (_feedPageSizeTotal / _feedPageLoads).toStringAsFixed(1) : 0} | Avg Duration: ${_feedPageLoads > 0 ? (_feedPageDurationTotal / _feedPageLoads).toStringAsFixed(1) : 0}ms');
    debugPrint('│ Waves Performance:  Page Loads: $_wavesPageLoads | Refreshes: $_wavesRefreshCount | Avg Size: ${_wavesPageLoads > 0 ? (_wavesPageSizeTotal / _wavesPageLoads).toStringAsFixed(1) : 0} | Avg Duration: ${_wavesPageLoads > 0 ? (_wavesPageDurationTotal / _wavesPageLoads).toStringAsFixed(1) : 0}ms');
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
