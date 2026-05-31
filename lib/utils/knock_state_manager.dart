import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Centralized Relationship Engine for KnockPost.
/// Maintains a single source of truth for all knock states and ensures
/// 100% real-time synchronization with Firestore using targeted document listeners.
class KnockStateManager {
  KnockStateManager._();
  static final KnockStateManager instance = KnockStateManager._();

  final Map<String, ValueNotifier<KnockStatus>> _notifiers = {};
  
  // Track active subscriptions to avoid duplicates.
  final Map<String, List<StreamSubscription>> _subscriptions = {};

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String? get _myUid => AuthService.instance.currentUser?.uid;

  /// Get the ValueNotifier for a user. Optionally seed it with an initial status.
  /// This will automatically trigger a Firestore listener to keep it in sync.
  ValueNotifier<KnockStatus> getNotifier(String otherUid, [KnockStatus? initial]) {
    if (!_notifiers.containsKey(otherUid)) {
      _notifiers[otherUid] = ValueNotifier<KnockStatus>(initial ?? KnockStatus.none);
    } else if (initial != null && initial != KnockStatus.none && !_subscriptions.containsKey(otherUid)) {
       // Only seed initial if we haven't already fetched from Firestore
       _notifiers[otherUid]!.value = initial;
    }
    
    // Ensure we are listening to this specific user's connection status
    _startListening(otherUid);
    
    return _notifiers[otherUid]!;
  }

  /// Manually set the status instantly (used for optimistic UI updates)
  void setOptimisticStatus(String otherUid, KnockStatus status) {
    if (!_notifiers.containsKey(otherUid)) {
      _notifiers[otherUid] = ValueNotifier<KnockStatus>(status);
    } else {
      _notifiers[otherUid]!.value = status;
    }
    // Listeners are still active, so if backend fails or overwrites, it will auto-correct.
  }

  void _startListening(String otherUid) {
    final me = _myUid;
    if (me == null || me == otherUid) return;

    if (_subscriptions.containsKey(otherUid)) {
      return; // Already listening to this user
    }

    bool iKnocked = false;
    String? iStatus;
    
    bool theyKnocked = false;
    String? theyStatus;

    void evaluateStatus() {
      KnockStatus currentStatus;
      
      if (!iKnocked && !theyKnocked) {
        currentStatus = KnockStatus.none;
      } else if (iKnocked && theyKnocked && iStatus == 'accepted' && theyStatus == 'accepted') {
        currentStatus = KnockStatus.mutualKnocked;
      } else if (iKnocked && iStatus == 'accepted' && !theyKnocked) {
        currentStatus = KnockStatus.knocked;
      } else if (iKnocked && iStatus == 'pending') {
        currentStatus = KnockStatus.pending;
      } else if (theyKnocked && !iKnocked) {
        if (theyStatus == 'pending') {
          currentStatus = KnockStatus.theyKnockedYouPending;
        } else {
          currentStatus = KnockStatus.theyKnockedYou;
        }
      } else {
        currentStatus = KnockStatus.none;
      }

      if (_notifiers.containsKey(otherUid)) {
        _notifiers[otherUid]!.value = currentStatus;
      } else {
        _notifiers[otherUid] = ValueNotifier<KnockStatus>(currentStatus);
      }
    }

    final docIdMeOther = '${me}_$otherUid';
    final docIdOtherMe = '${otherUid}_$me';

    // Set placeholder in map to prevent duplicate triggers
    _subscriptions[otherUid] = [];

    // Targeted direct document reads are highly efficient and multiplexed by Firebase
    final sub1 = _db.collection('connections').doc(docIdMeOther).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        iKnocked = true;
        iStatus = snap.data()!['status'] as String?;
      } else {
        iKnocked = false;
        iStatus = null;
      }
      evaluateStatus();
    });

    final sub2 = _db.collection('connections').doc(docIdOtherMe).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        theyKnocked = true;
        theyStatus = snap.data()!['status'] as String?;
      } else {
        theyKnocked = false;
        theyStatus = null;
      }
      evaluateStatus();
    });

    _subscriptions[otherUid] = [sub1, sub2];
  }

  /// Cancels all listeners and clears state (e.g. on logout)
  void clearAll() {
    for (var subs in _subscriptions.values) {
      for (var sub in subs) {
        sub.cancel();
      }
    }
    _subscriptions.clear();
    _notifiers.clear();
  }
}
