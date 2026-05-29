import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/haptic_helper.dart';
import '../login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _passController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_passController.text.isEmpty) {
      setState(() => _errorMsg = "Password is required");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete from Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      
      // Delete Firebase Auth
      await user.delete();

      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_registered', false);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _errorMsg = "Incorrect password. Please try again.");
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
          'Delete Account',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permanently Delete',
              style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'You are about to permanently delete your account and all associated data. This action cannot be undone. Please enter your password to confirm.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            
            Text(
              'PASSWORD',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passController,
              obscureText: _obscure,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Enter your password",
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: isDark ? Colors.white54 : Colors.black54),
                  onPressed: () {
                    KnockHaptics.selection();
                    setState(() { _obscure = !_obscure; });
                  },
                ),
              ),
            ),
            
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 14)),
            ],

            const Spacer(),
            
            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : () {
                  KnockHaptics.impact();
                  _deleteAccount();
                },
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Delete Account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
