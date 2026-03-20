import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    // Check if already verified first
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      // If already verified, immediately run the check logic to redirect
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkVerificationStatus();
      });
    } else {
      _createAccountAndVerify();
    }
  }

  Future<void> _createAccountAndVerify() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Configure ActionCodeSettings for passwordless link
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://knockpost-84b21.firebaseapp.com',
        handleCodeInApp: true,
        androidPackageName: 'com.example.knockpost',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: widget.email,
        actionCodeSettings: actionCodeSettings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sign-in link resent! Please check your email."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: [${e.code}] ${e.message}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
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
    await FirebaseAuth.instance.signOut();
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
      User? user = FirebaseAuth.instance.currentUser;
      await user?.reload(); 
      user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        // Email is verified! Now where do we go?
        
        // 1. Check if Firestore profile exists
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          if (userDoc.exists) {
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                    child: const Icon(Icons.arrow_back, size: 25, color: Colors.black),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 33,
                    width: 33,
                    child: Image.asset("assets/icon(white).png", fit: BoxFit.contain),
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
                    const Icon(Icons.link, size: 100, color: Colors.black12),
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
                      style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 48),
                    
                    isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Column(
                          children: [
                            const Text(
                              "Waiting for link...",
                              style: TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 40),
                            TextButton(
                              onPressed: isLoading ? null : () { KnockHaptics.tap(); _createAccountAndVerify(); }, // This now calls resend
                              child: const Text("Resend Sign-in Link", style: TextStyle(color: Colors.black)),
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
