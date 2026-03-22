import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_verification_screen.dart';
import '../login_screen.dart';

class SignupEmailScreen extends StatefulWidget {
  const SignupEmailScreen({super.key});

  @override
  State<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends State<SignupEmailScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  void goNext() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      debugPrint("Auth Stage 1: Storing email $email for link");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email_for_link', email);

      debugPrint("Auth Stage 2: Configuring ActionCodeSettings");
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://knockpost-84b21.firebaseapp.com', 
        handleCodeInApp: true,
        androidPackageName: 'com.example.knockpost',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      debugPrint("Auth Stage 3: Sending link to $email");
      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      debugPrint("Auth Stage 4: Link sent successfully");
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SignupVerificationScreen(
              email: email,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth ERROR (Firebase): [${e.code}] ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: [${e.code}] ${e.message}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Auth ERROR (Generic): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
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

  void goBackToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            // 🔥 Premium Header (slightly lowered)
            const SizedBox(height: 13),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [

                  GestureDetector(
                    onTap: () { KnockHaptics.tap(); goBackToLogin(); },
                    child: const Icon(
                      Icons.arrow_back,
                      size: 25,
                      color: Colors.black,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    height: 33,
                    width: 33,
                    child: Image.asset(
                      "assets/icon(white).png",
                      fit: BoxFit.contain,
                    ),
                  ),

                ],
              ),
            ),

            // 🔥 Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  30,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "What's your email address?",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      "Enter the email where we can reach you. This will be used to secure and access your account.",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: "Email address",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: isLoading ? null : () { KnockHaptics.tap(); goNext(); },
                      child: Container(
                        height: 58,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Next",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Center(
                      child: GestureDetector(
                        onTap: () { KnockHaptics.tap(); goBackToLogin(); },
                        child: const Text(
                          "I already have an account",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ),
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
