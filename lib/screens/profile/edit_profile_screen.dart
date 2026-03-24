import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/image_helper.dart';
import 'widgets/profile_ui_helpers.dart';

/// Edit Profile — edit name, username, bio, avatar, cover image, Open/Private toggle
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
  String? _avatarAsset;
  String? _coverAsset;

  static const int _maxBioWords = 70;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _privacyType = widget.user.privacyType;
    _avatarAsset = widget.user.avatarAsset;
    _coverAsset = widget.user.coverImageAsset;

    for (final ctrl in [_nameCtrl, _usernameCtrl, _bioCtrl]) {
      ctrl.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  int get _bioWordCount {
    final text = _bioCtrl.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  bool get _bioExceedsLimit => _bioWordCount > _maxBioWords;

  void _save() {
    if (_bioExceedsLimit) {
      KnockHaptics.impact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bio must be 70 words or less.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    KnockHaptics.impact();
    final updated = widget.user.copyWith(
      displayName: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      avatarAsset: _avatarAsset,
      coverImageAsset: _coverAsset,
      privacyType: _privacyType,
    );
    Navigator.pop(context, updated);
  }

  void _showImageOptions({
    required String title,
    required bool hasImage,
    required Future<void> Function(ImageSource source) onPickTap,
    required VoidCallback onRemoveTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: textColor),
                title: Text(
                  'Take photo',
                  style: TextStyle(color: textColor, fontSize: 14.5),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onPickTap(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: textColor),
                title: Text(
                  'Choose from gallery',
                  style: TextStyle(color: textColor, fontSize: 14.5),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onPickTap(ImageSource.gallery);
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Remove current photo',
                    style: TextStyle(color: Colors.red, fontSize: 14.5),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRemoveTap();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onChangeAvatar(ImageSource source) async {
    KnockHaptics.selection();
    final file = await ImageHelper.pickAndCropImage(
      context,
      source: source,
      cropRatioX: 1,
      cropRatioY: 1,
      isCircle: true,
      title: 'Crop Profile Photo',
    );
    if (file != null) {
      setState(() {
        _avatarAsset = file.path;
        _hasChanges = true;
      });
    }
  }

  void _onRemoveAvatar() {
    KnockHaptics.impact();
    setState(() {
      _avatarAsset = null;
      _hasChanges = true;
    });
  }

  Future<void> _onChangeCover(ImageSource source) async {
    KnockHaptics.selection();
    final file = await ImageHelper.pickAndCropImage(
      context,
      source: source,
      cropRatioX: 3,
      cropRatioY: 1,
      isCircle: false,
      title: 'Crop Cover Photo',
    );
    if (file != null) {
      setState(() {
        _coverAsset = file.path;
        _hasChanges = true;
      });
    }
  }

  void _onRemoveCover() {
    KnockHaptics.impact();
    setState(() {
      _coverAsset = null;
      _hasChanges = true;
    });
  }

  Widget _cameraBadge({
    required Color iconBg,
    required Color iconColor,
    Color? borderColor,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBg,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: Icon(
        Icons.camera_alt_rounded,
        size: 15,
        color: iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final fieldBg = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF6F6F6);
    final borderColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
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
                  color: _hasChanges
                      ? (isDark ? Colors.white : Colors.black)
                      : subColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 8),

            // ── Instagram-style Header Media Editor ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 210,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => _showImageOptions(
                        title: 'Cover Photo',
                        hasImage: _coverAsset != null,
                        onPickTap: _onChangeCover,
                        onRemoveTap: _onRemoveCover,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF222222)
                                : const Color(0xFFE5E5E5),
                            image: _coverAsset != null
                                ? DecorationImage(
                                    image: _coverAsset!.startsWith('assets/')
                                        ? AssetImage(_coverAsset!) as ImageProvider
                                        : FileImage(File(_coverAsset!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => _showImageOptions(
                          title: 'Cover Photo',
                          hasImage: _coverAsset != null,
                          onPickTap: _onChangeCover,
                          onRemoveTap: _onRemoveCover,
                        ),
                        child: _cameraBadge(
                          iconBg: Colors.black.withValues(alpha: 0.45),
                          iconColor: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _showImageOptions(
                          title: 'Profile Photo',
                          hasImage: _avatarAsset != null,
                          onPickTap: _onChangeAvatar,
                          onRemoveTap: _onRemoveAvatar,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: fieldBg,
                              backgroundImage: _avatarAsset != null
                                  ? (_avatarAsset!.startsWith('assets/')
                                      ? AssetImage(_avatarAsset!) as ImageProvider
                                      : FileImage(File(_avatarAsset!)))
                                  : null,
                              child: _avatarAsset == null
                                  ? Text(
                                      _nameCtrl.text.isNotEmpty
                                          ? _nameCtrl.text[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: _cameraBadge(
                                iconBg: Colors.black,
                                iconColor: Colors.white,
                                borderColor: bg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Fields ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Name
                  _FieldLabel('Display Name', subColor),
                  _EditField(
                    controller: _nameCtrl,
                    hint: 'Your name',
                    bg: fieldBg,
                    borderColor: borderColor,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 16),

                  // Username
                  _FieldLabel('Username', subColor),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _usernameCtrl,
                      style: TextStyle(fontSize: 14.5, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'your.username',
                        hintStyle: TextStyle(
                          color: textColor.withValues(alpha: 0.35),
                          fontSize: 14.5,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 2),
                          child: Text(
                            '@',
                            style: TextStyle(
                              color: subColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bio
                  _FieldLabel('Bio', subColor),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _bioExceedsLimit
                            ? Colors.red.withValues(alpha: 0.6)
                            : borderColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: _bioCtrl,
                          maxLines: 4,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: _bioExceedsLimit ? Colors.red : textColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'A little something about you...',
                            hintStyle: TextStyle(
                              color: textColor.withValues(alpha: 0.35),
                              fontSize: 14.5,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 8),
                          child: Text(
                            '$_bioWordCount/$_maxBioWords',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _bioExceedsLimit ? Colors.red : subColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Privacy toggle (only for Normal accounts) ─────────────
                  if (widget.user.accountType == AccountType.normal) ...[
                    Divider(
                      color: isDark
                          ? Colors.white12
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 8),
                    ProfileSettingsRow(
                      title: 'Private Account',
                      subtitle:
                          'Only accepted Knocks can see your profile & posts.',
                      trailing: Switch(
                        value: _privacyType == PrivacyType.private,
                        onChanged: (v) {
                          KnockHaptics.selection();
                          setState(() {
                            _privacyType = v
                                ? PrivacyType.private
                                : PrivacyType.open;
                            _hasChanges = true;
                          });
                        },
                        activeThumbColor: textColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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

  const _EditField({
    required this.controller,
    required this.hint,
    required this.bg,
    required this.borderColor,
    required this.textColor,
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
        style: TextStyle(fontSize: 14.5, color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: textColor.withValues(alpha: 0.35),
            fontSize: 14.5,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
