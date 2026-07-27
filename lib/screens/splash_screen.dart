import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'signup/signup_verification_screen.dart';
import 'signup/signup_username_screen.dart';
import '../../services/current_user_service.dart';
import '../../services/waves_feed_manager.dart';

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
    try {
      // 1. Isolate AppLinks so it doesn't crash the startup if it fails
      Uri? link;
      try {
        link = await AppLinks().getInitialLink().timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint("Splash: AppLinks failed - $e");
      }

      if (link != null) {
        debugPrint("Splash Detected Deep Link: ${link.toString()}");
      }

      // 2. Load SharedPreferences WITHOUT aggressive timeout
      // Slow devices need time to read from disk, especially after Play Store install
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint("Splash: SharedPreferences failed - $e");
      }

      // 3. Robust Auth State Check
      // We give Firebase up to 3 seconds to parse the local token.
      User? user = AuthService.instance.currentUser;
      if (user == null) {
        try {
          user = await AuthService.instance.authStateChanges
              .firstWhere((u) => u != null)
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          user = null;
        }
      }

      if (user != null) {
        if (!user.emailVerified) {
          _navigate(SignupVerificationScreen(email: user.email ?? ""));
          return;
        }

        // ⚡ ULTRA-FAST BYPASS: If we already confirmed they're registered before, skip Firestore!
        final isRegistered = prefs?.getBool('is_registered') ?? false;
        if (isRegistered) {
          await CurrentUserService.instance.loadCurrentUser().timeout(
            const Duration(seconds: 3), // Reduced timeout
            onTimeout: () {},
          );
          
          // 🔥 Pre-warm the Waves feed in the background so it's instantly ready
          WavesFeedManager.instance.loadInitial();
          
          _navigate(const HomeScreen());
          return;
        }

        // If not marked registered locally, check Firestore (prefer cache)
        Map<String, dynamic>? userProfile;
        bool fetchFailed = false;
        try {
          userProfile = await DatabaseService.instance.getUserProfile(user.uid, useCache: true);
        } catch (_) {
          try {
            userProfile = await DatabaseService.instance.getUserProfile(user.uid).timeout(const Duration(seconds: 5));
          } catch (_) {
            fetchFailed = true;
          }
        }

        if (mounted) {
          if (userProfile != null) {
            await prefs?.setBool('is_registered', true);
            await CurrentUserService.instance.loadCurrentUser().timeout(
              const Duration(seconds: 3),
              onTimeout: () {},
            );
            
            // 🔥 Pre-warm the Waves feed in the background so it's instantly ready
            WavesFeedManager.instance.loadInitial();
            
            _navigate(const HomeScreen());
          } else if (fetchFailed) {
            // Firestore fetch failed (offline/timeout) — don't punish the user
            // by sending them to signup. Trust Firebase Auth and go to HomeScreen.
            debugPrint('Splash: Firestore fetch failed, trusting Firebase Auth');
            await CurrentUserService.instance.loadCurrentUser().timeout(
              const Duration(seconds: 3),
              onTimeout: () {},
            );
            WavesFeedManager.instance.loadInitial();
            _navigate(const HomeScreen());
          } else {
            // Firestore fetch succeeded but returned null = truly new user
            _navigate(
              SignupUsernameScreen(email: user.email ?? "", isGoogleSignup: true),
            );
          }
        }
      } else {
        _navigate(const LoginScreen());
      }
    } catch (e, stack) {
      debugPrint("Error in startApp: $e\n$stack");
      FlutterNativeSplash.remove(); // Force remove splash screen on any error
      if (mounted) {
        // Fallback navigation if anything throws/times out
        try {
          if (AuthService.instance.currentUser != null) {
            WavesFeedManager.instance.loadInitial();
            _navigate(const HomeScreen());
          } else {
            _navigate(const LoginScreen());
          }
        } catch (_) {
          _navigate(const LoginScreen());
        }
      }
    }
  }



  void _navigate(Widget screen) {
    FlutterNativeSplash.remove();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF16181C),
      body: SizedBox(),
    );
  }
}
