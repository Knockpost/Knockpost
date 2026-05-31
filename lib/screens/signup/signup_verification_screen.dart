import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../../utils/haptic_helper.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'signup_username_screen.dart';

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
  State<SignupVerificationScreen> createState() => _SignupVerificationScreenState();
}

class _SignupVerificationScreenState extends State<SignupVerificationScreen> {
  bool isChecking = false;
  bool isResending = false;

  void verifyOtp(String code) async {
    setState(() {
      isChecking = true;
    });

    try {
      await AuthService.instance.verifyEmailOtp(
        email: widget.email, 
        otp: code,
      );
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SignupUsernameScreen(
              email: widget.email,
              password: widget.password,
              isGoogleSignup: widget.password == null,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("OTP Verification Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid or expired code")),
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

  void resendOtp() async {
    setState(() {
      isResending = true;
    });

    try {
      await AuthService.instance.sendEmailOtp(email: widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend code: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  void goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      AuthService.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: TextStyle(fontSize: 22, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
    );

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
                    onTap: () { KnockHaptics.tap(); goBack(); },
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter 6-digit code",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "We sent a code to\n${widget.email}",
                      style: TextStyle(fontSize: 15, color: isDark ? Colors.white54 : Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 36),
                    
                    Center(
                      child: Pinput(
                        length: 6,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: defaultPinTheme.copyWith(
                          decoration: defaultPinTheme.decoration!.copyWith(
                            border: Border.all(color: isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                        onCompleted: (pin) {
                          verifyOtp(pin);
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    if (isChecking)
                      const Center(child: KnockPostLoadingIndicator()),
                      
                    const SizedBox(height: 20),
                    
                    Center(
                      child: GestureDetector(
                        onTap: isResending ? null : () { KnockHaptics.tap(); resendOtp(); },
                        child: Text(
                          isResending ? "Resending..." : "I didn't get a code",
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.w700,
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
