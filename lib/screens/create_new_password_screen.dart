import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../utils/haptic_helper.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../../widgets/instagram_password_field.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  
  const CreateNewPasswordScreen({super.key, required this.email, required this.otp});

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool _isPasswordValid = false;
  final GlobalKey<State<InstagramPasswordField>> _passwordFieldKey = GlobalKey();

  void updatePassword() async {
    final pass = passwordController.text.trim();

    if (!_isPasswordValid) {
      if (_passwordFieldKey.currentState != null) {
        (_passwordFieldKey.currentState as dynamic).triggerShake();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid password")));
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthService.instance.resetPasswordWithOtp(
        email: widget.email,
        otp: widget.otp,
        newPassword: pass,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully. Please log in.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Update Password ERROR: $e");
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const SizedBox(width: 25), // No back button since they shouldn't go back to VerifyOTP
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
                padding: EdgeInsets.fromLTRB(24, 30, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Create New Password",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Your new password must be different from previous used passwords.",
                      style: TextStyle(fontSize: 15, color: isDark ? Colors.white54 : Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 36),
                    
                    InstagramPasswordField(
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
                      onTap: (!_isPasswordValid || isLoading) ? null : () { KnockHaptics.tap(); updatePassword(); },
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
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: KnockpostLoadingIndicator())
                              : Text("Save & Login", style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white, 
                                  fontSize: 17, 
                                  fontWeight: FontWeight.w600
                                )),
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
