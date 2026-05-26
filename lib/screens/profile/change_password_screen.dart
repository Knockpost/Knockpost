import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/haptic_helper.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_oldPassController.text.isEmpty || _newPassController.text.isEmpty) {
      setState(() => _errorMsg = "Both fields are required");
      return;
    }
    if (_newPassController.text.length < 6) {
      setState(() => _errorMsg = "New password must be at least 6 characters");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _oldPassController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPassController.text);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _errorMsg = "Incorrect current password");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xfff8f8f8);
    final textColor = isDark ? Colors.white : Colors.black;

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
          'Change Password',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update your password',
              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enter your current password to verify your identity, then enter your new password.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            
            // Current Password Field
            Text(
              'CURRENT PASSWORD',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _oldPassController,
              obscureText: _obscureOld,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Enter current password",
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility, color: isDark ? Colors.white54 : Colors.black54),
                  onPressed: () {
                    KnockHaptics.selection();
                    setState(() { _obscureOld = !_obscureOld; });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // New Password Field
            Text(
              'NEW PASSWORD',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPassController,
              obscureText: _obscureNew,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Enter new password",
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: isDark ? Colors.white54 : Colors.black54),
                  onPressed: () {
                    KnockHaptics.selection();
                    setState(() { _obscureNew = !_obscureNew; });
                  },
                ),
              ),
            ),
            
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 14)),
            ],

            const Spacer(),
            
            // Update Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D88FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : () {
                  KnockHaptics.impact();
                  _updatePassword();
                },
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Update Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
