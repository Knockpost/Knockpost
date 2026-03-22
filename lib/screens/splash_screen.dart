import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

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
    startApp();
  }

  Future<void> startApp() async {
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

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (!user.emailVerified) {
        _navigate(SignupVerificationScreen(email: user.email ?? ""));
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          _navigate(const HomeScreen());
        } else {
          _navigate(SignupUsernameScreen(
            email: user.email ?? "",
            isGoogleSignup: true,
          ));
        }
      }
    } else {
      _navigate(const LoginScreen());
    }
  }

  Future<void> _handleEmailLink(String link) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email_for_link');

      if (email == null) {
        throw Exception("No email found in SharedPreferences.");
      }

      await FirebaseAuth.instance.signInWithEmailLink(
        email: email,
        emailLink: link,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        _navigate(SignupUsernameScreen(email: email, isGoogleSignup: true));
      }
    } catch (e) {
      debugPrint("Email Link Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Link Verification Failed: $e")),
        );
        _navigate(const LoginScreen());
      }
    }
  }

  void _navigate(Widget screen) {
    if (!mounted) return;
    FlutterNativeSplash.remove();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(),
    );
  }
}
