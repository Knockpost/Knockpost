import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'theme/theme_controller.dart';
import 'utils/audio_lifecycle_manager.dart';
import 'services/view_batch_service.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

// গ্লোবাল স্টপওয়াচ এবং লগ ফাংশন
final appStopwatch = Stopwatch()..start();
void authLog(String message) {
  debugPrint("AUTH_TRACE [${appStopwatch.elapsedMilliseconds}ms]: $message");
}

class AuthLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    authLog("Lifecycle = ${state.name}");
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  runZonedGuarded<Future<void>>(() async {
    try {
      WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      WidgetsBinding.instance.addObserver(AuthLifecycleObserver());
      
      authLog("Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}");
      authLog("Build mode: ${kReleaseMode ? 'Release' : (kProfileMode ? 'Profile' : 'Debug')}");
      
      // Reduce VisibilityDetector polling from 100ms (default) to 500ms.
      // View counting has a 2-second timer guard, so 500ms is plenty.
      VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 500);
      AudioLifecycleManager.instance.init();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
      
      authLog("Starting Firebase.initializeApp");
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      authLog("Firebase.initializeApp completed");

      FirebaseAuth.instance.idTokenChanges().listen((user) {
        authLog("idTokenChanges fired = ${user?.uid}");
      });
      FirebaseAuth.instance.userChanges().listen((user) {
        authLog("userChanges fired = ${user?.uid}");
      });
      FirebaseAuth.instance.authStateChanges().listen((user) {
        authLog("authStateChanges fired = ${user?.uid}");
      });

      authLog("currentUser instantly after init = ${FirebaseAuth.instance.currentUser?.uid}");

      await ViewBatchService.instance.init();
      
      authLog("Starting AppCheck.activate");
      // ── S5: Advanced Threat Protection (App Check) ──
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      authLog("AppCheck.activate completed");
      
      authLog("currentUser after AppCheck = ${FirebaseAuth.instance.currentUser?.uid}");

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // ── Crashlytics: capture all Flutter framework errors ──
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('HttpException')) {
          return; // Ignore HttpException from cached_network_image to prevent Crashlytics spam
        }
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // ── Crashlytics: capture platform dispatcher errors ──
      PlatformDispatcher.instance.onError = (error, stack) {
        if (error.toString().contains('HttpException')) {
          return true; // Ignore HttpException
        }
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Enable true edge-to-edge mode — content renders behind system bars (like YouTube)
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false, // KEY: disables Android's auto scrim
          statusBarColor: Colors.transparent,
        ),
      );
      // ── Image cache tuning ────────────────────────────────────────────────────
      // Default Flutter cache: 100MB / 1000 images. We bump this so that
      // feed images stay in memory longer and don't re-download on re-scroll.
      PaintingBinding.instance.imageCache.maximumSizeBytes = 300 << 20; // 300 MB
      PaintingBinding.instance.imageCache.maximumSize = 500; // max 500 images

      authLog("Calling runApp()");
      runApp(const MyApp());
    } catch (e, stack) {
      if (e is FirebaseAuthException) {
        authLog("Fatal FirebaseAuthException code=${e.code}, message=${e.message}");
      } else {
        authLog("Fatal Error in main: $e");
      }
      debugPrint("Startup Error: $e\n$stack");
      FlutterNativeSplash.remove();
      runApp(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Failed to start app:\n$e",
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }, (error, stack) {
    // ── Crashlytics: capture all uncaught async errors ──
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
  });
}

class _AppScrollBehavior extends ScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // ClampingScrollPhysics keeps posts still while scrolling — no bounce
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Remove Android glow indicator globally
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'KnockPost',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          scrollBehavior: const _AppScrollBehavior(),
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.getSystemUiOverlayStyle(context),
              child: child!,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
