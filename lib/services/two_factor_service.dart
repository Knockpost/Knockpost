import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TwoFactorService {
  static final TwoFactorService instance = TwoFactorService._internal();
  TwoFactorService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if 2FA is enabled for the current user
  Future<bool> is2FAEnabled() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      final data = doc.data();
      return data?['twoFactorEnabled'] == true;
    } catch (e) {
      debugPrint('Error checking 2FA status: $e');
      return false;
    }
  }

  /// Send OTP to user's email via Cloud Function
  Future<bool> sendOtp() async {
    try {
      final callable = _functions.httpsCallable('sendOtp');
      final result = await callable.call();
      return result.data['success'] == true;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }

  /// Verify the OTP via Cloud Function
  Future<Map<String, dynamic>> verifyOtp(String code) async {
    try {
      final callable = _functions.httpsCallable('verifyOtp');
      final result = await callable.call({'code': code});
      return {
        'success': result.data['success'] == true,
        'message': result.data['message'] ?? '',
      };
    } catch (e) {
      String errorMessage = 'Verification failed';
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'permission-denied':
            errorMessage = 'Incorrect OTP';
            break;
          case 'deadline-exceeded':
            errorMessage = 'OTP has expired. Please request a new one.';
            break;
          case 'not-found':
            errorMessage = 'No OTP found. Please request a new one.';
            break;
          default:
            errorMessage = e.message ?? 'Verification failed';
        }
      }
      debugPrint('Error verifying OTP: $e');
      return {'success': false, 'message': errorMessage};
    }
  }

  /// Enable 2FA for the current user
  Future<void> enable2FA() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'twoFactorEnabled': true,
    });
  }

  /// Disable 2FA for the current user
  Future<void> disable2FA() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'twoFactorEnabled': false,
    });
  }
}
