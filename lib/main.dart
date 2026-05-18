import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'theme/theme_controller.dart';
import 'utils/audio_lifecycle_manager.dart';

void main() async {
  try {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    AudioLifecycleManager.instance.init();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

    runApp(const MyApp());
  } catch (e, stack) {
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
          debugShowCheckedModeBanner: false,
          title: 'Knockpost',
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
