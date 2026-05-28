import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/two_factor_service.dart';
import '../../utils/haptic_helper.dart';
import 'otp_verification_screen.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  bool _is2FAEnabled = false;
  bool _isLoading = true;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _load2FAStatus();
  }

  Future<void> _load2FAStatus() async {
    final enabled = await TwoFactorService.instance.is2FAEnabled();
    if (mounted) {
      setState(() {
        _is2FAEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _enable2FA() async {
    setState(() => _isToggling = true);

    // Send OTP first
    final sent = await TwoFactorService.instance.sendOtp();

    if (!mounted) return;

    if (!sent) {
      setState(() => _isToggling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send verification code. Please try again.')),
      );
      return;
    }

    setState(() => _isToggling = false);

    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    // Navigate to OTP screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            purpose: 'Enable Two-Step Verification',
            onVerified: () async {
              // OTP verified — enable 2FA
              await TwoFactorService.instance.enable2FA();
              if (mounted) {
                Navigator.pop(context); // Pop OTP screen
                setState(() => _is2FAEnabled = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Two-step verification enabled!')),
                );
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _disable2FA() async {
    setState(() => _isToggling = true);

    // Send OTP to verify identity before disabling
    final sent = await TwoFactorService.instance.sendOtp();

    if (!mounted) return;

    if (!sent) {
      setState(() => _isToggling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send verification code. Please try again.')),
      );
      return;
    }

    setState(() => _isToggling = false);

    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    // Navigate to OTP screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            purpose: 'Disable Two-Step Verification',
            onVerified: () async {
              // OTP verified — disable 2FA
              await TwoFactorService.instance.disable2FA();
              if (mounted) {
                Navigator.pop(context); // Pop OTP screen
                setState(() => _is2FAEnabled = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Two-step verification disabled.')),
                );
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xfff8f8f8);
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Two-Step Verification',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shield icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _is2FAEnabled
                            ? const Color(0xFF2D88FF).withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _is2FAEnabled ? Icons.shield_rounded : Icons.shield_outlined,
                        size: 36,
                        color: _is2FAEnabled
                            ? const Color(0xFF2D88FF)
                            : (isDark ? Colors.white54 : Colors.black38),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _is2FAEnabled
                            ? const Color(0xFF2D88FF).withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _is2FAEnabled ? '● Enabled' : '○ Disabled',
                        style: TextStyle(
                          color: _is2FAEnabled ? const Color(0xFF2D88FF) : Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'What is Two-Step Verification?',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Two-step verification adds an extra layer of security to your account. When enabled, you\'ll need to enter a verification code sent to your email every time you log in.',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Benefits list
                  _BenefitItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Prevents unauthorized access',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _BenefitItem(
                    icon: Icons.email_outlined,
                    title: 'Verification code sent to your email',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _BenefitItem(
                    icon: Icons.timer_outlined,
                    title: 'Code expires in 5 minutes',
                    isDark: isDark,
                  ),

                  const Spacer(),

                  // Enable / Disable Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _is2FAEnabled
                            ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                            : const Color(0xFF2D88FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: _is2FAEnabled
                              ? BorderSide(color: Colors.red.withValues(alpha: 0.5))
                              : BorderSide.none,
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isToggling
                          ? null
                          : () {
                              KnockHaptics.impact();
                              if (_is2FAEnabled) {
                                _disable2FA();
                              } else {
                                _enable2FA();
                              }
                            },
                      child: _isToggling
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _is2FAEnabled
                                  ? 'Disable Two-Step Verification'
                                  : 'Enable Two-Step Verification',
                              style: TextStyle(
                                color: _is2FAEnabled ? Colors.red : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2D88FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF2D88FF)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
