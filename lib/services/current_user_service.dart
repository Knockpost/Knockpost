import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// App-wide current logged-in user state.
/// Listen to [userNotifier] to rebuild UI when user data changes.
class CurrentUserService {
  CurrentUserService._();
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
    } catch (e) {
      debugPrint('CurrentUserService.loadCurrentUser error: $e');
      userNotifier.value = null;
    }
  }

  /// User data update করার পরে (e.g. profile edit) refresh করো
  Future<void> refresh() => loadCurrentUser();

  /// Logout-এ call করো
  void clear() => userNotifier.value = null;
}
