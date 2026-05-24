import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../../utils/haptic_helper.dart';
import '../../services/database_service.dart';
import 'signup_password_screen.dart';
import 'profile_setup_screen.dart';
import '../login_screen.dart';
import '../../widgets/instagram_username_field.dart';

class SignupUsernameScreen extends StatefulWidget {
  final String email;
  final String? password; // Optional: regular signup passed it after verification
  final bool isGoogleSignup;
  const SignupUsernameScreen({
    super.key,
    required this.email,
    this.password,
    this.isGoogleSignup = false,
  });

  @override
  State<SignupUsernameScreen> createState() =>
      _SignupUsernameScreenState();
}

class _SignupUsernameScreenState
    extends State<SignupUsernameScreen> {

  final TextEditingController usernameController =
      TextEditingController();
  
  bool isLoading = false;
  bool _isUsernameValid = false;

  void goNext() async {
    if (!_isUsernameValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid and available username")),
      );
      return;
    }

    final username = usernameController.text.trim();
    if (username.isEmpty) return;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupPasswordScreen(
            email: widget.email,
            username: username,
            isGoogleSignup: widget.isGoogleSignup,
          ),
        ),
      );
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
                      "Choose a username",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "This will be your unique identity on KnockPost.",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white54 : Colors.black54,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    InstagramUsernameField(
                      controller: usernameController,
                      autofocus: true,
                      onValidityChanged: (isValid) {
                        setState(() {
                          _isUsernameValid = isValid;
                        });
                      },
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: (!_isUsernameValid || isLoading) ? null : () { KnockHaptics.tap(); goNext(); },
                      child: Container(
                        height: 58,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _isUsernameValid 
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white24 : Colors.black26),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: KnockpostLoadingIndicator(),
                                )
                              : Text(
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
