import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'signup/signup_verification_screen.dart';
import 'signup/signup_username_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // Fullscreen enable
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    startApp();
  }

  Future<void> startApp() async {

    await Future.delayed(const Duration(seconds: 1));

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // 1. Check if the app was opened via an Email Link (using app_links)
    final appLinks = AppLinks();
    final link = await appLinks.getInitialLink();
    
    if (link != null) {
      final linkString = link.toString();
      debugPrint("Splash Detected Email Link: $linkString");
      if (FirebaseAuth.instance.isSignInWithEmailLink(linkString)) {
        await _handleEmailLink(linkString);
        return;
      }
    }

    // Check Firebase Auth state
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // 1. Check if email is verified
      if (!user.emailVerified) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SignupVerificationScreen(
                email: user.email ?? "",
              ),
            ),
          );
        }
        return;
      }

      // 2. Check if Firestore profile exists
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          // Both verified and profile exists -> Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        } else {
          // Verified but no profile -> Setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SignupUsernameScreen(
                email: user.email ?? "",
                isGoogleSignup: true,
              ),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }

  }

  Future<void> _handleEmailLink(String link) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email_for_link');

      if (email == null) {
        throw Exception("No email found in SharedPreferences. Please use the same device.");
      }

      // Complete sign in
      await FirebaseAuth.instance.signInWithEmailLink(
        email: email,
        emailLink: link,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        // Successful link sign in -> Go to Pick Username!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SignupUsernameScreen(
              email: email,
              isGoogleSignup: true, // Use this flag to indicate no password yet
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Email Link Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Link Verification Failed: $e")),
        );
        // Fallback to login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),

          child: Image.asset(
            'assets/icon.png',
            width: 150,
            height: 150,
          ),
        ),
      ),

    );

  }

}
