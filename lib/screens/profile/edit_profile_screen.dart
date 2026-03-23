import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import 'widgets/profile_ui_helpers.dart';

/// Edit Profile — edit name, username, bio, avatar, Open/Private toggle
class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  late PrivacyType _privacyType;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _privacyType = widget.user.privacyType;

    for (final ctrl in [_nameCtrl, _usernameCtrl, _bioCtrl]) {
      ctrl.addListener(() => setState(() => _hasChanges = true));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _save() {
    KnockHaptics.impact();
    final updated = widget.user.copyWith(
      displayName: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      privacyType: _privacyType,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final fieldBg =
        isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF6F6F6);
    final borderColor =
        isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          leadingWidth: 80,
          centerTitle: true,
          title: Text(
            'Edit Profile',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _hasChanges ? _save : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _hasChanges ? textColor : subColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Avatar ───────────────────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: fieldBg,
                    child: Text(
                      _nameCtrl.text.isNotEmpty
                          ? _nameCtrl.text[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 15, color: bg),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Fields ───────────────────────────────────────────────────────
            _FieldLabel('Display Name', subColor),
            _EditField(
              controller: _nameCtrl,
              hint: 'Your name',
              bg: fieldBg,
              borderColor: borderColor,
              textColor: textColor,
            ),
            const SizedBox(height: 16),

            _FieldLabel('Username', subColor),
            _EditField(
              controller: _usernameCtrl,
              hint: 'your.username',
              bg: fieldBg,
              borderColor: borderColor,
              textColor: textColor,
              prefix: Text('@',
                  style: TextStyle(color: subColor, fontSize: 15)),
            ),
            const SizedBox(height: 16),

            _FieldLabel('Bio', subColor),
            _EditField(
              controller: _bioCtrl,
              hint: 'A little something about you...',
              bg: fieldBg,
              borderColor: borderColor,
              textColor: textColor,
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // ── Privacy toggle (only for Normal accounts) ─────────────────
            if (widget.user.accountType == AccountType.normal) ...[
              Divider(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
              const SizedBox(height: 8),
              ProfileSettingsRow(
                title: 'Private Account',
                subtitle: 'Only accepted Knocks can see your profile & posts.',
                trailing: Switch(
                  value: _privacyType == PrivacyType.private,
                  onChanged: (v) {
                    KnockHaptics.selection();
                    setState(() {
                      _privacyType =
                          v ? PrivacyType.private : PrivacyType.open;
                      _hasChanges = true;
                    });
                  },
                  activeThumbColor: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _FieldLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color bg;
  final Color borderColor;
  final Color textColor;
  final int maxLines;
  final Widget? prefix;

  const _EditField({
    required this.controller,
    required this.hint,
    required this.bg,
    required this.borderColor,
    required this.textColor,
    this.maxLines = 1,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14.5, color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: textColor.withValues(alpha: 0.35), fontSize: 14.5),
          prefixIcon: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, top: 14),
                  child: prefix,
                )
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
