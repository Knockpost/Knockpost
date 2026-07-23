import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// App-wide current logged-in user state.
/// Listen to [userNotifier] to rebuild UI when user data changes.
class CurrentUserService with WidgetsBindingObserver {
  CurrentUserService._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final CurrentUserService instance = CurrentUserService._();

  /// Null মানে এখনো load হয়নি বা logged out
  final ValueNotifier<UserModel?> userNotifier = ValueNotifier(null);

  UserModel? get currentUser => userNotifier.value;

  /// Splash বা Login-এর পরে একবার call করো।
  /// Firestore থেকে user data load করে [userNotifier]-এ set করে।
  Future<void> loadCurrentUser() async {
    try {
      final User? firebaseUser = AuthService.instance.currentUser;
      if (firebaseUser == null) {
        userNotifier.value = null;
        return;
      }

      final data = await DatabaseService.instance.getUserProfile(firebaseUser.uid);
      if (data == null) {
        userNotifier.value = null;
        return;
      }

      userNotifier.value = UserModel.fromMap(data, firebaseUser.uid).copyWith(
        isOwnProfile: true,
      );
      
      // Update online status when loaded
      _updateOnlineStatus(true);
    } catch (e) {
      debugPrint('CurrentUserService.loadCurrentUser error: $e');
      userNotifier.value = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      _updateOnlineStatus(false);
    }
  }

  void _updateOnlineStatus(bool isOnline) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    };
    if (isOnline) {
      updates['lastAppOpenedAt'] = FieldValue.serverTimestamp();
    }
    
    FirebaseFirestore.instance.collection('users').doc(uid).update(updates).catchError((_) {});
  }

  /// User data update করার পরে (e.g. profile edit) refresh করো
  Future<void> refresh() => loadCurrentUser();

  /// Logout-এ call করো
  void clear() {
    _updateOnlineStatus(false);
    userNotifier.value = null;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
