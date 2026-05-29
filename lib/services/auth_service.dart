import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // You might want to match this with the client ID from login_screen.dart
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '56941114478-99oi3tmack3hmtelf5l0vp6j4oe8hson.apps.googleusercontent.com',
  );

  User? get currentUser => _auth.currentUser;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Logs in a user using Email and Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Creates a new user with Email and Password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a 6-digit OTP to the user's email via Cloud Functions
  Future<void> sendEmailOtp({required String email}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('sendEmailOtp');
    await callable.call({'email': email});
  }

  /// Verifies the 6-digit OTP (just checks if it's valid)
  Future<bool> verifyEmailOtp({required String email, required String otp}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('verifyEmailOtp');
    await callable.call({'email': email, 'otp': otp});
    return true; // if no error is thrown, it's valid
  }

  /// Resets the password using OTP directly via backend
  Future<void> resetPasswordWithOtp({required String email, required String otp, required String newPassword}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('resetPasswordWithOtp');
    await callable.call({'email': email, 'otp': otp, 'newPassword': newPassword});
  }

  /// Triggers the Google Sign-In flow
  Future<UserCredential?> signInWithGoogle() async {
    await _googleSignIn.signOut().catchError((_) => null);

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return null; // Canceled by user
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Logs out the user
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut().catchError((_) => null);
  }
}
