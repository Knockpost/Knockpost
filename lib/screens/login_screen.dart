import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup/signup_email_screen.dart';
import 'signup/signup_username_screen.dart';
import 'signup/signup_verification_screen.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context) {

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,

      body: SizedBox(
        height: screenHeight,
        width: screenWidth,

        child: Stack(
          children: [

            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),

                    child: Column(
                      children: [

                        Image.asset(
                          isDark ? "assets/icon(drak background).png" : "assets/icon(light backgroud).png",
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),

                        const SizedBox(height: 14),

                        Text(
                          "Only You Matters",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black54,
                            letterSpacing: 0.4,
                          ),
                        ),

                        const SizedBox(height: 48),

                        TextField(
                          controller: userController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: "Email",
                            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: "Password",
                            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2),

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),

                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              onPressed: () {
                                KnockHaptics.selection();
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          height: 54,

                          child: ElevatedButton(

                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              elevation: 0,
                              shadowColor: Colors.transparent,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            onPressed: isLoading ? null : () {
                              KnockHaptics.tap();
                              login();
                            },

                            child: isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: isDark ? Colors.black : Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Log in",
                                    style: TextStyle(
                                      color: isDark ? Colors.black : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        Row(
                          children: [

                            const Expanded(child: Divider()),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                "OR",
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ),

                            const Expanded(child: Divider()),

                          ],
                        ),

                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          height: 54,

                          child: OutlinedButton(

                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            onPressed: isLoading ? null : () {
                              KnockHaptics.tap();
                              signInWithGoogle();
                            },

                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [

                                Image.asset(
                                  "assets/google.png",
                                  width: 22,
                                ),

                                const SizedBox(width: 10),

                                Text(
                                  "Continue with Google",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        GestureDetector(
                          onTap: () {
                            KnockHaptics.tap();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupEmailScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Don't have an account? Sign up",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  // 🔥 LOGIN LOGIC
  Future<void> login() async {
    final email = userController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'An error occurred during login.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userCredential = await AuthService.instance.signInWithGoogle();
      
      if (!mounted) return;
      
      if (userCredential != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in with Google: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

}
