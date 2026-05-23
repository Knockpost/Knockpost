import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import 'database_service.dart';

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

    final docId = _docId(me, toUid);
    final status = isOpenProfile ? 'accepted' : 'pending';
    try {
      await _col.doc(docId).set({
        'fromUid': me,
        'toUid': toUid,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification
      NotificationService.instance.sendNotification(
        receiverUid: toUid,
        type: NotificationType.knock,
      );

      // Increment stats
      await _db.collection('users').doc(toUid).update({
        'totalKnocksReceived': FieldValue.increment(1),
      }).catchError((_) {}); // Ignore if document doesn't exist
      DatabaseService.instance.recalculateCreatorRank(toUid);
    } catch (e) {
      debugPrint('ConnectionService.sendKnock error: $e');
      rethrow;
    }
  }

  /// Accept an incoming knock from [fromUid] (= knock back).
  /// Updates the existing {fromUid}_{myUid} document to 'accepted'.
  Future<void> acceptKnock(String fromUid) async {
    final me = _myUid;
    if (me == null) return;
    try {
      final batch = _db.batch();
      
      // Update their knock to accepted
      batch.update(_col.doc(_docId(fromUid, me)), {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Create my knock to them as accepted
      batch.set(_col.doc(_docId(me, fromUid)), {
        'fromUid': me,
        'toUid': fromUid,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();

      // Send a notification that we knocked back
      NotificationService.instance.sendNotification(
        receiverUid: fromUid,
        type: NotificationType.knock,
      );
    } catch (e) {
      debugPrint('ConnectionService.acceptKnock error: $e');
      rethrow;
    }
  }

  /// Remove / withdraw a knock.
  /// Deletes the {myUid}_{otherUid} document.
  Future<void> removeKnock(String otherUid) async {
    final me = _myUid;
    if (me == null) return;
    try {
      await _col.doc(_docId(me, otherUid)).delete();

      // Decrement stats
      await _db.collection('users').doc(otherUid).update({
        'totalKnocksReceived': FieldValue.increment(-1),
      }).catchError((_) {});
      DatabaseService.instance.recalculateCreatorRank(otherUid);
    } catch (e) {
      debugPrint('ConnectionService.removeKnock error: $e');
      rethrow;
    }
  }

  /// Approve an incoming knock from [fromUid] without knocking back.
  /// Updates the existing {fromUid}_{myUid} document to 'accepted'.
  Future<void> approveKnock(String fromUid) async {
    final me = _myUid;
    if (me == null) return;
    try {
      await _col.doc(_docId(fromUid, me)).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Optionally notify them that you accepted
      NotificationService.instance.sendNotification(
        receiverUid: fromUid,
        type: NotificationType.knock, // Or a specific 'accepted' type if available
      );
    } catch (e) {
      debugPrint('ConnectionService.approveKnock error: $e');
      rethrow;
    }
  }

  /// Decline an incoming knock from [fromUid] — just delete the document.
  Future<void> declineKnock(String fromUid) async {
    final me = _myUid;
    if (me == null) return;
    try {
      await _col.doc(_docId(fromUid, me)).delete();

      // Decrement stats
      await _db.collection('users').doc(me).update({
        'totalKnocksReceived': FieldValue.increment(-1),
      }).catchError((_) {});
      DatabaseService.instance.recalculateCreatorRank(me);
    } catch (e) {
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
    // Query both directions and intersect in the map
    return _col
        .where('fromUid', isEqualTo: me)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((sentSnap) async {
          final sentToUids = sentSnap.docs
              .map((d) => (d.data() as Map)['toUid'] as String)
              .toSet();

          // For each sent-accepted connection, check if they also accepted back
          final mutuals = <String>[];
          for (final uid in sentToUids) {
            final reverseDoc = await _col.doc(_docId(uid, me)).get();
            if (reverseDoc.exists) {
              final reverseStatus = (reverseDoc.data() as Map)['status'];
              if (reverseStatus == 'accepted') mutuals.add(uid);
            }
          }
          return mutuals;
        });
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
