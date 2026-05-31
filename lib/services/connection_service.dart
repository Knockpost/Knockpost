import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import 'database_service.dart';
import '../utils/knock_state_manager.dart';
import 'performance_service.dart';

/// Handles all Knock / Connection logic.
///
/// Firestore schema:
///   connections/{fromUid}_{toUid}
///     fromUid : string
///     toUid   : string
///     status  : 'pending' | 'accepted'
///     createdAt : Timestamp
///     updatedAt : Timestamp
class ConnectionService {
  ConnectionService._();
  static final ConnectionService instance = ConnectionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('connections');

  String? get _myUid => AuthService.instance.currentUser?.uid;

  String _docId(String a, String b) => '${a}_$b';

  // ── Send / Accept knock ──────────────────────────────────────────────────────

  /// Knock on [toUid].
  /// • Open profile  → immediately creates 'accepted' document (mutual)
  /// • Private profile → creates 'pending' document
  Future<void> sendKnock({
    required String toUid,
    required bool isOpenProfile,
  }) async {
    final me = _myUid;
    if (me == null) return;

    final currentStatus = KnockStateManager.instance.getNotifier(toUid).value;
    if (currentStatus == KnockStatus.pending || currentStatus == KnockStatus.knocked || currentStatus == KnockStatus.mutualKnocked) {
      return; // Prevent duplicate sending
    }

    final docId = _docId(me, toUid);
    final status = isOpenProfile ? 'accepted' : 'pending';
    
    final previousStatus = currentStatus;
    final nextStatus = isOpenProfile ? KnockStatus.knocked : KnockStatus.pending;
    KnockStateManager.instance.setOptimisticStatus(toUid, nextStatus);

    try {
      await _col.doc(docId).set({
        'fromUid': me,
        'toUid': toUid,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification only on first knock
      NotificationService.instance.sendNotification(
        receiverUid: toUid,
        type: NotificationType.knock,
      );

      // Increment stats
      await _db.collection('users').doc(toUid).update({
        'totalKnocksReceived': FieldValue.increment(1),
      }).catchError((_) {}); 
      DatabaseService.instance.recalculateCreatorRank(toUid);
    } catch (e) {
      KnockStateManager.instance.setOptimisticStatus(toUid, previousStatus);
      debugPrint('ConnectionService.sendKnock error: $e');
      rethrow;
    }
  }

  /// Accept an incoming knock from [fromUid] (= knock back).
  /// Updates the existing {fromUid}_{myUid} document to 'accepted'.
  Future<void> acceptKnock(String fromUid) async {
    final me = _myUid;
    if (me == null) return;
    
    final currentStatus = KnockStateManager.instance.getNotifier(fromUid).value;
    if (currentStatus == KnockStatus.mutualKnocked) return; 

    final previousStatus = currentStatus;
    KnockStateManager.instance.setOptimisticStatus(fromUid, KnockStatus.mutualKnocked);

    try {
      final batch = _db.batch();
      
      // Update their knock to accepted
      batch.set(_col.doc(_docId(fromUid, me)), {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Create my knock to them as accepted
      batch.set(_col.doc(_docId(me, fromUid)), {
        'fromUid': me,
        'toUid': fromUid,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // CREATE MUTUAL CONNECTION
      final sortedUids = [me, fromUid]..sort();
      final mutualId = '${sortedUids[0]}_${sortedUids[1]}';
      batch.set(_db.collection('mutual_connections').doc(mutualId), {
        'participants': [sortedUids[0], sortedUids[1]],
        'establishedAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();

      // Send a notification that we knocked back
      NotificationService.instance.sendNotification(
        receiverUid: fromUid,
        type: NotificationType.knockBack,
      );
    } catch (e) {
      KnockStateManager.instance.setOptimisticStatus(fromUid, previousStatus);
      debugPrint('ConnectionService.acceptKnock error: $e');
      rethrow;
    }
  }

  /// Remove / withdraw a knock.
  /// Deletes the {myUid}_{otherUid} document.
  Future<void> removeKnock(String otherUid) async {
    final me = _myUid;
    if (me == null) return;
    
    final currentStatus = KnockStateManager.instance.getNotifier(otherUid).value;
    final previousStatus = currentStatus;
    
    KnockStatus nextStatus = KnockStatus.none;
    if (currentStatus == KnockStatus.mutualKnocked) {
      nextStatus = KnockStatus.theyKnockedYou;
    }
    KnockStateManager.instance.setOptimisticStatus(otherUid, nextStatus);

    try {
      final batch = _db.batch();
      batch.delete(_col.doc(_docId(me, otherUid)));

      // DELETE MUTUAL CONNECTION
      final sortedUids = [me, otherUid]..sort();
      final mutualId = '${sortedUids[0]}_${sortedUids[1]}';
      batch.delete(_db.collection('mutual_connections').doc(mutualId));
      
      await batch.commit();

      // Clean up the notification we sent them
      NotificationService.instance.deleteSentNotification(otherUid, 'knock_$me');

      // Decrement stats
      await _db.collection('users').doc(otherUid).update({
        'totalKnocksReceived': FieldValue.increment(-1),
      }).catchError((_) {});
      DatabaseService.instance.recalculateCreatorRank(otherUid);
    } catch (e) {
      KnockStateManager.instance.setOptimisticStatus(otherUid, previousStatus);
      debugPrint('ConnectionService.removeKnock error: $e');
      rethrow;
    }
  }

  /// Approve an incoming knock from [fromUid] without knocking back.
  /// Updates the existing {fromUid}_{myUid} document to 'accepted'.
  Future<void> approveKnock(String fromUid) async {
    final me = _myUid;
    if (me == null) return;
    
    final currentStatus = KnockStateManager.instance.getNotifier(fromUid).value;
    final previousStatus = currentStatus;
    
    KnockStateManager.instance.setOptimisticStatus(fromUid, KnockStatus.theyKnockedYou);

    try {
      await _col.doc(_docId(fromUid, me)).set({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Optionally notify them that you accepted
      NotificationService.instance.sendNotification(
        receiverUid: fromUid,
        type: NotificationType.knockAccept,
      );
    } catch (e) {
      KnockStateManager.instance.setOptimisticStatus(fromUid, previousStatus);
      debugPrint('ConnectionService.approveKnock error: $e');
      rethrow;
    }
  }

  /// Decline an incoming knock from [fromUid] — just delete the document.
  Future<void> declineKnock(String fromUid) async {
    final me = _myUid;
    if (me == null) return;

    final currentStatus = KnockStateManager.instance.getNotifier(fromUid).value;
    final previousStatus = currentStatus;
    
    KnockStateManager.instance.setOptimisticStatus(fromUid, KnockStatus.none);

    try {
      final batch = _db.batch();
      batch.delete(_col.doc(_docId(fromUid, me)));

      // DELETE MUTUAL CONNECTION (Just in case it was mutual)
      final sortedUids = [me, fromUid]..sort();
      final mutualId = '${sortedUids[0]}_${sortedUids[1]}';
      batch.delete(_db.collection('mutual_connections').doc(mutualId));
      
      await batch.commit();

      // Clean up their pending notification to us
      NotificationService.instance.deleteNotification('knock_$fromUid');

      // Decrement stats
      await _db.collection('users').doc(me).update({
        'totalKnocksReceived': FieldValue.increment(-1),
      }).catchError((_) {});
      DatabaseService.instance.recalculateCreatorRank(me);
    } catch (e) {
      KnockStateManager.instance.setOptimisticStatus(fromUid, previousStatus);
      debugPrint('ConnectionService.declineKnock error: $e');
      rethrow;
    }
  }

  // ── Status query ─────────────────────────────────────────────────────────────

  /// Returns the current [KnockStatus] between the logged-in user and [otherUid].
  Future<KnockStatus> getKnockStatus(String otherUid) async {
    final me = _myUid;
    if (me == null) return KnockStatus.none;

    try {
      // Check if I knocked them
      final iKnockedSnap = await _col.doc(_docId(me, otherUid)).get();
      // Check if they knocked me
      final theyKnockedSnap = await _col.doc(_docId(otherUid, me)).get();

      final iKnocked = iKnockedSnap.exists;
      final theyKnocked = theyKnockedSnap.exists;

      if (!iKnocked && !theyKnocked) return KnockStatus.none;

      final iStatus = iKnocked ? (iKnockedSnap.data() as Map)['status'] : null;
      final theyStatus = theyKnocked ? (theyKnockedSnap.data() as Map)['status'] : null;

      // Both accepted → mutual
      if (iKnocked && theyKnocked &&
          iStatus == 'accepted' && theyStatus == 'accepted') {
        return KnockStatus.mutualKnocked;
      }

      // I knocked and accepted (open profile case) → knocked
      if (iKnocked && iStatus == 'accepted' && !theyKnocked) {
        return KnockStatus.knocked;
      }

      // I knocked, still pending
      if (iKnocked && iStatus == 'pending') return KnockStatus.pending;

      // They knocked me
      if (theyKnocked && !iKnocked) {
        if (theyStatus == 'pending') {
          return KnockStatus.theyKnockedYouPending;
        }
        return KnockStatus.theyKnockedYou;
      }

      return KnockStatus.none;
    } catch (e) {
      debugPrint('ConnectionService.getKnockStatus error: $e');
      return KnockStatus.none;
    }
  }

  // ── Real-time streams ─────────────────────────────────────────────────────────

  /// Stream of UIDs that the current user has knocked (sent).
  Stream<List<String>> streamSentKnockUids() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    return _col
        .where('fromUid', isEqualTo: me)
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data() as Map)['toUid'] as String).toList());
  }

  /// Stream of UIDs that the current user has knocked and are currently pending.
  Stream<List<String>> streamSentPendingKnockUids() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    return _col
        .where('fromUid', isEqualTo: me)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data() as Map)['toUid'] as String).toList());
  }

  /// Stream of UIDs that the current user has knocked and are currently accepted.
  Stream<List<String>> streamSentAcceptedKnockUids() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    return _col
        .where('fromUid', isEqualTo: me)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data() as Map)['toUid'] as String).toList());
  }

  /// Stream of incoming knocks that are currently pending.
  Stream<List<String>> streamIncomingPendingKnockUids() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    return _col
        .where('toUid', isEqualTo: me)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data() as Map)['fromUid'] as String).toList());
  }

  /// Stream of incoming knocks that are currently accepted.
  Stream<List<String>> streamIncomingAcceptedKnockUids() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    return _col
        .where('toUid', isEqualTo: me)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data() as Map)['fromUid'] as String).toList());
  }

  /// Stream of UIDs that are mutual connections (both sides have 'accepted').
  Stream<List<String>> streamMutualConnectionUids() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    
    // Phase Connection Graph: O(1) query instead of O(N) read storm
    return _db.collection('mutual_connections')
        .where('participants', arrayContains: me)
        .snapshots()
        .map((snap) {
          // Record telemetry: we prevented N reads per emission where N = snap.docs.length
          PerformanceService.instance.addConnectionGraphReadsPrevented(snap.docs.length);
          
          return snap.docs.map((d) {
            final parts = List<String>.from((d.data() as Map)['participants'] ?? []);
            return parts.firstWhere((id) => id != me, orElse: () => '');
          }).where((uid) => uid.isNotEmpty).toList();
        });
  }

  // ── One-time Fetches (Phase C3 Optimization) ──────────────────────────────────

  Future<List<String>> getSentKnockUids() async {
    final me = _myUid;
    if (me == null) return [];
    try {
      final snap = await _col.where('fromUid', isEqualTo: me).get();
      PerformanceService.instance.incrementReadCount(snap.docs.length);
      return snap.docs.map((d) => (d.data() as Map)['toUid'] as String).toList();
    } catch (_) { return []; }
  }

  Future<List<String>> getSentPendingKnockUids() async {
    final me = _myUid;
    if (me == null) return [];
    try {
      final snap = await _col.where('fromUid', isEqualTo: me).where('status', isEqualTo: 'pending').get();
      PerformanceService.instance.incrementReadCount(snap.docs.length);
      return snap.docs.map((d) => (d.data() as Map)['toUid'] as String).toList();
    } catch (_) { return []; }
  }

  Future<List<String>> getSentAcceptedKnockUids() async {
    final me = _myUid;
    if (me == null) return [];
    try {
      final snap = await _col.where('fromUid', isEqualTo: me).where('status', isEqualTo: 'accepted').get();
      PerformanceService.instance.incrementReadCount(snap.docs.length);
      return snap.docs.map((d) => (d.data() as Map)['toUid'] as String).toList();
    } catch (_) { return []; }
  }

  Future<List<String>> getIncomingPendingKnockUids() async {
    final me = _myUid;
    if (me == null) return [];
    try {
      final snap = await _col.where('toUid', isEqualTo: me).where('status', isEqualTo: 'pending').get();
      PerformanceService.instance.incrementReadCount(snap.docs.length);
      return snap.docs.map((d) => (d.data() as Map)['fromUid'] as String).toList();
    } catch (_) { return []; }
  }

  Future<List<String>> getIncomingAcceptedKnockUids() async {
    final me = _myUid;
    if (me == null) return [];
    try {
      final snap = await _col.where('toUid', isEqualTo: me).where('status', isEqualTo: 'accepted').get();
      PerformanceService.instance.incrementReadCount(snap.docs.length);
      return snap.docs.map((d) => (d.data() as Map)['fromUid'] as String).toList();
    } catch (_) { return []; }
  }

  Future<List<String>> getMutualConnectionUids() async {
    final me = _myUid;
    if (me == null) return [];
    try {
      final snap = await _db.collection('mutual_connections').where('participants', arrayContains: me).get();
      PerformanceService.instance.incrementReadCount(snap.docs.length);
      return snap.docs.map((d) {
        final parts = List<String>.from((d.data() as Map)['participants'] ?? []);
        return parts.firstWhere((id) => id != me, orElse: () => '');
      }).where((uid) => uid.isNotEmpty).toList();
    } catch (_) { return []; }
  }

  /// Fetch UIDs of all people who knocked a specific user (accepted knocks only).
  /// Returns user IDs whose knock to [targetUid] has status 'accepted'.
  Future<List<String>> getKnockerUids(String targetUid) async {
    try {
      final snap = await _col
          .where('toUid', isEqualTo: targetUid)
          .where('status', isEqualTo: 'accepted')
          .get();
      return snap.docs
          .map((d) => (d.data() as Map)['fromUid'] as String)
          .toList();
    } catch (e) {
      debugPrint('ConnectionService.getKnockerUids error: $e');
      return [];
    }
  }
}
