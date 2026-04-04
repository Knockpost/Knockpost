import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/system_nav_bar_fill.dart';
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
  String? _avatarAsset;
  String? _coverImageAsset;

  bool _hasChanges = false;
  final ImagePicker _picker = ImagePicker();

  int get _bioWordCount => _bioCtrl.text
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .length;

  bool get _canSave {
    if (!_hasChanges) return false;
    if (_bioWordCount > 40) return false;
    return true;
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: Colors.white,
            dimmedLayerColor: Colors.black.withValues(alpha: 0.8),
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white24,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            resetButtonHidden: true,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _avatarAsset = croppedFile.path;
          _hasChanges = true;
        });
      }
    }
  }

  Future<void> _pickCover(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 2, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Cover Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: Colors.white,
            dimmedLayerColor: Colors.black.withValues(alpha: 0.8),
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white24,
            initAspectRatio: CropAspectRatioPreset.ratio3x2,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Cover Photo',
            aspectRatioLockEnabled: true,
            resetButtonHidden: true,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _coverImageAsset = croppedFile.path;
          _hasChanges = true;
        });
      }
    }
  }

  void _showImageSourceBottomSheet({required bool isAvatar}) {
    KnockHaptics.selection();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: subColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: textColor),
                  title: Text(
                    'Choose from library',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isAvatar) {
                      _pickAvatar(ImageSource.gallery);
                    } else {
                      _pickCover(ImageSource.gallery);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: textColor),
                  title: Text(
                    'Take photo',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isAvatar) {
                      _pickAvatar(ImageSource.camera);
                    } else {
                      _pickCover(ImageSource.camera);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remove current picture',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isAvatar) {
                      setState(() {
                        _avatarAsset = null;
                        _hasChanges = true;
                      });
                    } else {
                      setState(() {
                        _coverImageAsset = null;
                        _hasChanges = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _privacyType = widget.user.privacyType;
    _avatarAsset = widget.user.avatarAsset;
    _coverImageAsset = widget.user.coverImageAsset;

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
      avatarAsset: _avatarAsset,
      clearAvatar: _avatarAsset == null,
      coverImageAsset: _coverImageAsset,
      clearCover: _coverImageAsset == null,
    );
    Navigator.pop(context, updated);
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
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
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
              onPressed: _canSave ? _save : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _canSave ? textColor : subColor,
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
            // ── Cover & Avatar Stack ───────────────────────────────────────
            SizedBox(
              height: 176,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover Photo Background
                  Align(
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showImageSourceBottomSheet(isAvatar: false),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(16),
                      image: _coverImageAsset != null
                          ? DecorationImage(
                              image: _coverImageAsset!.startsWith('assets/')
                                  ? AssetImage(_coverImageAsset!)
                                        as ImageProvider
                                  : FileImage(File(_coverImageAsset!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                ),
                ),
                // Cover Photo Camera Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => _showImageSourceBottomSheet(isAvatar: false),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Overlapping Avatar (Bottom Right)
                Positioned(
                  bottom: 0,
                  right: 16,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _showImageSourceBottomSheet(isAvatar: true),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bg,
                            border: Border.all(color: bg, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: fieldBg,
                            backgroundImage: _avatarAsset != null
                                ? (_avatarAsset!.startsWith('assets/')
                                          ? AssetImage(_avatarAsset!)
                                          : FileImage(File(_avatarAsset!)))
                                      as ImageProvider
                                : null,
                            child: _avatarAsset == null
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 56,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      // Avatar Camera Button
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () =>
                              _showImageSourceBottomSheet(isAvatar: true),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: textColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 2),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: bg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
            const SizedBox(height: 24),

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
              prefixText: '@',
            ),
            const SizedBox(height: 16),

            _FieldLabel('Bio', subColor),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _bioCtrl,
              builder: (context, value, child) {
                final wordCount = value.text
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((e) => e.isNotEmpty)
                    .length;
                final isOver = wordCount > 40;
                return Stack(
                  children: [
                    _EditField(
                      controller: _bioCtrl,
                      hint: 'A little something about you...',
                      bg: fieldBg,
                      borderColor: isOver
                          ? Colors.red.withValues(alpha: 0.5)
                          : borderColor,
                      textColor: textColor,
                      maxLines: 4,
                      contentPadding: const EdgeInsets.only(
                        left: 14,
                        right: 14,
                        top: 12,
                        bottom: 30, // Extra space at bottom to avoid overlap
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 12,
                      child: Text(
                        '$wordCount/40',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOver ? Colors.red : subColor,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Privacy toggle (only for Normal accounts) ─────────────────
            if (widget.user.accountType == AccountType.normal) ...[
              Divider(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 8),
              ProfileSettingsRow(
                title: 'Private Account',
                subtitle: 'Only accepted Knocks can see your profile & posts.',
                trailing: Switch(
                  value: _privacyType == PrivacyType.private,
                  onChanged: (v) {
                    KnockHaptics.selection();
                    setState(() {
                      _privacyType = v ? PrivacyType.private : PrivacyType.open;
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
          SystemNavBarFill(color: bg),
        ],
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
  final int maxLines;
  final String? prefixText;
  final EdgeInsetsGeometry? contentPadding;

  const _EditField({
    required this.controller,
    required this.hint,
    required this.bg,
    required this.borderColor,
    required this.textColor,
    this.maxLines = 1,
    this.prefixText,
    this.contentPadding,
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
            color: textColor.withValues(alpha: 0.35),
            fontSize: 14.5,
          ),
          prefixText: prefixText != null ? '$prefixText ' : null,
          prefixStyle: TextStyle(
            color: textColor.withValues(alpha: 0.5),
            fontSize: 14.5,
          ),
          contentPadding:
              contentPadding ??
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}
