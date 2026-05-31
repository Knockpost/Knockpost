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
      // Run initialization concurrently to slash wait times
      final futures = await Future.wait([
        AppLinks().getInitialLink(),
        SharedPreferences.getInstance(),
      ]).timeout(const Duration(seconds: 5)); // Reduced to 5s for faster fallback

      final link = futures[0] as Uri?;
      final prefs = futures[1] as SharedPreferences;

      if (link != null) {
        final linkString = link.toString();
        debugPrint("Splash Detected Deep Link: $linkString");
      }

      final user = AuthService.instance.currentUser;

      if (user != null) {
        if (!user.emailVerified) {
          _navigate(SignupVerificationScreen(email: user.email ?? ""));
          return;
        }

        // ⚡ ULTRA-FAST BYPASS: If we already confirmed they're registered before, skip Firestore!
        final isRegistered = prefs.getBool('is_registered') ?? false;
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
        try {
          userProfile = await DatabaseService.instance.getUserProfile(user.uid, useCache: true);
        } catch (_) {
          try {
            userProfile = await DatabaseService.instance.getUserProfile(user.uid).timeout(const Duration(seconds: 5));
          } catch (_) {}
        }

        if (mounted) {
          if (userProfile != null) {
            await prefs.setBool('is_registered', true);
            await CurrentUserService.instance.loadCurrentUser().timeout(
              const Duration(seconds: 3),
              onTimeout: () {},
            );
            
            // 🔥 Pre-warm the Waves feed in the background so it's instantly ready
            WavesFeedManager.instance.loadInitial();
            
            _navigate(const HomeScreen());
          } else {
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
