import 'dart:async';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:app_links/app_links.dart';
import 'profile_setup_screen.dart';
import 'signup_username_screen.dart';
import '../home_screen.dart';
import '../login_screen.dart';

class SignupVerificationScreen extends StatefulWidget {
  final String email;
  final String? username;
  final String? password;

  const SignupVerificationScreen({
    super.key,
    required this.email,
    this.username,
    this.password,
  });

  @override
  State<SignupVerificationScreen> createState() =>
      _SignupVerificationScreenState();
}

class _SignupVerificationScreenState
    extends State<SignupVerificationScreen> {
  
  bool isLoading = false;
  bool isChecking = false;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    
    // Check if already verified first
    User? user = AuthService.instance.currentUser;
    if (user != null && user.emailVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkVerificationStatus();
      });
    }
    // Removed _createAccountAndVerify() call as it's redundant (sent from previous screen)
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Listen to incoming links while the app is open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Verification Screen Detected Link: $uri');
      _handleIncomingLink(uri.toString());
    });
  }

  Future<void> _handleIncomingLink(String link) async {
    // Note: isSignInWithEmailLink is a method on FirebaseAuth instance, so we can use a helper or directly access _auth if exposed. However, we'll use FirebaseAuth.instance directly here just for the check, or we could add it to AuthService.
    // To keep it simple without adding to AuthService just for that:
    if (!FirebaseAuth.instance.isSignInWithEmailLink(link)) return;

    setState(() {
      isChecking = true;
    });

    try {
      await AuthService.instance.signInWithEmailLink(
        email: widget.email,
        emailLink: link,
      );
      
      // After signing in, refresh status
      await checkVerificationStatus();
    } catch (e) {
      debugPrint("Email Link Verification Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification Failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isChecking = false;
        });
      }
    }
  }

  Future<void> _createAccountAndVerify() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint("Auth Stage 2 (Resend): Configuring ActionCodeSettings");
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://knockpost-84b21.firebaseapp.com',
        handleCodeInApp: true,
        androidPackageName: 'com.example.knockpost',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      debugPrint("Auth Stage 3 (Resend): Sending link to ${widget.email}");
      await AuthService.instance.sendSignInLinkToEmail(
        email: widget.email,
        actionCodeSettings: actionCodeSettings,
      );

      debugPrint("Auth Stage 4 (Resend): Link resent successfully");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sign-in link resent! Please check your email."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth ERROR (Resend - Firebase): [${e.code}] ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: [${e.code}] ${e.message}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Auth ERROR (Resend - Generic): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  void goBackAndLogout() async {
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> checkVerificationStatus() async {
    setState(() {
      isChecking = true;
    });

    try {
      User? user = AuthService.instance.currentUser;
      await user?.reload(); 
      user = AuthService.instance.currentUser;

      if (user != null && user.emailVerified) {
        // Email is verified! Now where do we go?
        
        // 1. Check if Firestore profile exists
        final userProfile = await DatabaseService.instance.getUserProfile(user.uid);

        if (mounted) {
          if (userProfile != null) {
            // Profile exists -> Home
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          } else {
            // No profile -> Pick a username
            // We pass the password if we have it (Regular signup) 
            // so we don't ask for it again later.
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => SignupUsernameScreen(
                  email: widget.email,
                  password: widget.password, 
                  isGoogleSignup: widget.password == null,
                ),
              ),
              (route) => false,
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Email not verified yet. Please check your inbox.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error checking status: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { KnockHaptics.tap(); goBackAndLogout(); },
                    child: Icon(Icons.arrow_back, size: 25, color: isDark ? Colors.white : Colors.black),
                  ),
                  const Spacer(),
                  Image.asset(
                    isDark ? "assets/icon(drak background).png" : "assets/icon(light backgroud).png",
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.link, size: 100, color: isDark ? Colors.white12 : Colors.black12),
                    const SizedBox(height: 30),
                    const Text(
                      "Check your email",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "We've sent a sign-in link to\n${widget.email}.\n\nClick the link in that email to verify your account and continue setting up your profile.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: isDark ? Colors.white54 : Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 48),
                    
                    isLoading 
                      ? const KnockpostLoadingIndicator()
                      : Column(
                          children: [
                            Text(
                              "Waiting for link...",
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 20),

                            TextButton(
                              onPressed: isChecking ? null : () { 
                                KnockHaptics.tap(); 
                                checkVerificationStatus(); 
                              },
                              child: isChecking 
                                  ? const SizedBox(width: 20, height: 20, child: KnockpostLoadingIndicator())
                                  : Text("I've already verified", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: isLoading ? null : () { KnockHaptics.tap(); _createAccountAndVerify(); }, // This now calls resend
                              child: Text("Resend Sign-in Link", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
