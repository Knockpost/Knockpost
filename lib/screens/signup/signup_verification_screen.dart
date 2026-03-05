import 'package:flutter/material.dart';
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
      User? user = FirebaseAuth.instance.currentUser;

      // If we are not signed in OR signed in as a different user
      if (user == null || user.email != widget.email) {
        // Only try to create account if password was provided (Signup flow)
        if (widget.password != null) {
          UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                  email: widget.email, password: widget.password!);
          user = userCredential.user;
        } else {
          // If no password, we expect the user to already be signed in via Login
          // If they aren't, this is an invalid state
          if (user == null) {
            throw Exception("Session expired. Please log in again.");
          }
        }
      }

      // 2. Send verification email
      await user?.sendEmailVerification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification link sent! Please check your email inbox.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null && user.email == widget.email) {
          await user.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Account exists. Verification link resent!")),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("This email is already registered. Try logging in.")),
            );
          }
        }
      } else {
        if (mounted) {
          debugPrint("Firebase Verification Error: [${e.code}] - ${e.message}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: [${e.code}] ${e.message}"),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 10),
            ),
          );
        }
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
            // No profile -> Check if we have the data passed in
            if (widget.username != null && widget.password != null) {
              // Coming from Signup flow, we have the data
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileSetupScreen(
                    email: widget.email,
                    username: widget.username!,
                    password: widget.password!,
                  ),
                ),
              );
            } else {
              // Coming from Login, but no profile -> Need to pick a username
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => SignupUsernameScreen(
                    email: widget.email,
                    isGoogleSignup: true, // This flag bypasses password setup
                  ),
                ),
                (route) => false,
              );
            }
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
                    onTap: goBackAndLogout,
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
                    const Icon(Icons.mark_email_unread_outlined, size: 100, color: Colors.black12),
                    const SizedBox(height: 30),
                    const Text(
                      "Verify your email",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "We've sent a verification link to\n${widget.email}.\n\nPlease click the link in that email to continue.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 48),
                    
                    isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: isChecking ? null : checkVerificationStatus,
                                child: isChecking 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                                  : const Text("I have verified my email", style: TextStyle(color: Colors.white, fontSize: 16)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: isLoading ? null : _createAccountAndVerify,
                              child: const Text("Resend Verification Email", style: TextStyle(color: Colors.black)),
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