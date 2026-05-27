import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../utils/haptic_helper.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/current_user_service.dart';
import 'signup/signup_email_screen.dart';
import 'signup/signup_username_screen.dart';
import 'signup/signup_verification_screen.dart';
import 'home_screen.dart';
import 'profile/otp_verification_screen.dart';
import '../widgets/legal_agreement_text.dart';
import '../services/two_factor_service.dart';
import 'forgot_password_screen.dart';

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
  }

  @override
  Widget build(BuildContext context) {

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,

      // IMPORTANT: disable resize
      resizeToAvoidBottomInset: false,

      body: SizedBox(
        height: screenHeight,
        width: screenWidth,

        child: Stack(
          children: [

            /// CENTER CONTENT (ABSOLUTE FIXED)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),

                    child: Column(
                      children: [

                        /// ICON
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

                        /// USERNAME
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

                        /// PASSWORD
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

                        const SizedBox(height: 8),

                        /// FORGOT PASSWORD
                        Align(
                          alignment: Alignment.centerRight,
                          child: _OpacityButton(
                            onTap: () {
                              KnockHaptics.tap();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ForgotPasswordScreen(
                                    initialEmail: userController.text.trim(),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Text(
                                "Forgot password?",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// LOGIN BUTTON (NO SHADOW)
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
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: KnockpostLoadingIndicator(),
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

                        /// DIVIDER
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

                        /// GOOGLE BUTTON
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

                        const SizedBox(height: 10),

                        const LegalAgreementText(),

                        const SizedBox(height: 10),

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

      final user = AuthService.instance.currentUser;
      if (user != null && mounted) {
        final userProfile = await DatabaseService.instance.getUserProfile(user.uid);

        if (!mounted) return;

        if (!user.emailVerified) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignupVerificationScreen(
                email: user.email ?? "",
              ),
            ),
          );
          return;
        }

        if (userProfile != null) {
          // Check 2FA
          final is2FA = await TwoFactorService.instance.is2FAEnabled();
          if (is2FA) {
            // Send OTP
            await TwoFactorService.instance.sendOtp();
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  email: user.email ?? '',
                  purpose: 'Login Verification',
                  onVerified: () async {
                    await CurrentUserService.instance.loadCurrentUser();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
            );
          } else {
            await CurrentUserService.instance.loadCurrentUser();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => SignupUsernameScreen(
                email: user.email ?? "",
                isGoogleSignup: true,
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint("Login Error: $e");
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

  Future<void> signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      await AuthService.instance.signInWithGoogle();

      final user = AuthService.instance.currentUser;
      if (user != null) {
        final userProfile = await DatabaseService.instance.getUserProfile(user.uid);

        if (mounted) {
          // Google users are pre-verified, so we skip SignupVerificationScreen entirely
          if (userProfile != null) {
            // Check 2FA
            final is2FA = await TwoFactorService.instance.is2FAEnabled();
            if (is2FA) {
              // Send OTP
              await TwoFactorService.instance.sendOtp();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OtpVerificationScreen(
                    email: user.email ?? '',
                    purpose: 'Login Verification',
                    onVerified: () async {
                      await CurrentUserService.instance.loadCurrentUser();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ),
              );
            } else {
              await CurrentUserService.instance.loadCurrentUser();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            }
          } else {
            // New Google user -> Pick a username first
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => SignupUsernameScreen(
                  email: user.email ?? "",
                  isGoogleSignup: true,
                ),
              ),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Google Sign-In Detailed Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Sign-In failed. Error: $e"),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: "Details",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Sign-In Error Details"),
                    content: SingleChildScrollView(child: Text(e.toString())),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                    ],
                  ),
                );
              },
            ),
          ),
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
}

class _OpacityButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _OpacityButton({required this.child, required this.onTap});

  @override
  State<_OpacityButton> createState() => _OpacityButtonState();
}

class _OpacityButtonState extends State<_OpacityButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _isDown ? 0.5 : 1.0,
        child: widget.child,
      ),
    );
  }
}
