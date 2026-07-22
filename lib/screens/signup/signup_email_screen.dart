import 'package:flutter/material.dart';
import 'dart:async';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../../utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_verification_screen.dart';
import '../login_screen.dart';
import '../../widgets/legal_agreement_text.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class SignupEmailScreen extends StatefulWidget {
  const SignupEmailScreen({super.key});

  @override
  State<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends State<SignupEmailScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  bool isCheckingEmail = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String val) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final email = val.trim();
    if (email.isNotEmpty && email.contains('@')) {
      setState(() {
        isCheckingEmail = true;
      });
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        bool emailTaken = await DatabaseService.instance.checkEmailTaken(email);
        if (mounted) {
          setState(() {
            isCheckingEmail = false;
            if (emailTaken) {
              _errorMessage = "You already have an account with this email.";
            }
          });
        }
      });
    } else {
      setState(() {
        isCheckingEmail = false;
      });
    }
  }

  void goNext() async {
    // Dismiss the keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if email already exists in Database
      bool emailTaken = await DatabaseService.instance.checkEmailTaken(email);
      if (emailTaken) {
        if (mounted) {
          setState(() { 
            isLoading = false; 
            _errorMessage = "You already have an account with this email.";
          });
        }
        return;
      }

      debugPrint("Auth Stage 1: Storing email $email for link");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email_for_link', email);

      debugPrint("Auth Stage 2: Sending OTP to $email");
      await AuthService.instance.sendEmailOtp(email: email);

      debugPrint("Auth Stage 3: OTP sent successfully");
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
        String errorText = e.message ?? "Authentication failed.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Auth ERROR (Generic): $e");
      if (mounted) {
        String errorText = "Something went wrong. Please try again.";
        if (e.toString().contains("exhausted")) {
          errorText = "Too many attempts. Please try again later.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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

                    Text(
                      "Enter the email where we can reach you. This will be used to secure and access your account.",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white54 : Colors.black54,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: _errorMessage != null
                            ? Border.all(color: Colors.redAccent, width: 1.5)
                            : null,
                      ),
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        onChanged: _onEmailChanged,
                        decoration: InputDecoration(
                          hintText: "Email address",
                          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                          border: InputBorder.none,
                          suffixIcon: isCheckingEmail
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
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
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: KnockPostLoadingIndicator(
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                )
                              : Text(
                                  "Next",
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Center(
                      child: GestureDetector(
                        onTap: () { KnockHaptics.tap(); goBackToLogin(); },
                        child: Text(
                          "I already have an account",
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

            // 🔥 Bottom section — pinned to bottom, professional look
            const LegalAgreementText(),

          ],
        ),
      ),
    );
  }
}
