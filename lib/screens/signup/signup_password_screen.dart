import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_verification_screen.dart';
import 'profile_setup_screen.dart';
import '../login_screen.dart';
import '../../widgets/knockpost_password_field.dart';
import '../../services/auth_service.dart';

class SignupPasswordScreen extends StatefulWidget {
  final String email;
  final String? username; // Optional now: regular signup doesn't have it yet
  final bool isGoogleSignup;
  const SignupPasswordScreen({
    super.key,
    required this.email,
    this.username,
    this.isGoogleSignup = false,
  });

  @override
  State<SignupPasswordScreen> createState() =>
      _SignupPasswordScreenState();
}

class _SignupPasswordScreenState
    extends State<SignupPasswordScreen> {

  final TextEditingController passwordController =
      TextEditingController();

  bool isLoading = false;
  bool _isPasswordValid = false;
  final GlobalKey<State<KnockpostPasswordField>> _passwordFieldKey = GlobalKey();

  void goNext() async {
    final password = passwordController.text.trim();
    if (!_isPasswordValid) {
      if (_passwordFieldKey.currentState != null) {
        (_passwordFieldKey.currentState as dynamic).triggerShake();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid password")),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (widget.isGoogleSignup && user != null) {
        // For Google Signup, user is already signed in
        await user.updatePassword(password);
      } else {
        // For Email OTP Signup, user is NOT created yet
        await AuthService.instance.createUserWithEmailAndPassword(
          email: widget.email,
          password: password,
        );
      }

      if (mounted) {
        // After setting password/creating account, go to Profile Setup
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              email: widget.email,
              username: widget.username ?? "User", 
              password: password,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint("Password Setting Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not set password: ${e.toString()}")),
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

  void goBack() {
    Navigator.pop(context);
  }

  void goLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            // 🔥 Same Premium Header
            const SizedBox(height: 13),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [

                  GestureDetector(
                    onTap: () { KnockHaptics.tap(); goBack(); },
                    child: Icon(
                      Icons.arrow_back,
                      size: 25,
                      color: isDark ? Colors.white : Colors.black,
                    ),
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
                      "Create a password",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Make sure it's strong and secure.",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white54 : Colors.black54,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    KnockpostPasswordField(
                      key: _passwordFieldKey,
                      controller: passwordController,
                      autofocus: true,
                      onValidityChanged: (isValid) {
                        setState(() {
                          _isPasswordValid = isValid;
                        });
                      },
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: (!_isPasswordValid || isLoading) ? null : () { KnockHaptics.tap(); goNext(); },
                      child: Container(
                        height: 58,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _isPasswordValid 
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white24 : Colors.black26),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Next",
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
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
                        onTap: () { KnockHaptics.tap(); goLogin(); },
                        child: Text(
                          "Already have an account? Log in",
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white54 : Colors.black54,
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
