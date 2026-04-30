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
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  AudioLifecycleManager.instance.init();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Force non-edge-to-edge mode so system nav bar is opaque
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  // ── Image cache tuning ────────────────────────────────────────────────────
  // Default Flutter cache: 100MB / 1000 images. We bump this so that
  // feed images stay in memory longer and don't re-download on re-scroll.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 300 << 20; // 300 MB
  PaintingBinding.instance.imageCache.maximumSize     = 500;        // max 500 images

  runApp(const MyApp());
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
      BuildContext context, Widget child, ScrollableDetails details) {
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
