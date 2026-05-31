import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/current_user_service.dart';
import '../../services/image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/system_nav_bar_fill.dart';
import '../../widgets/knockpost_username_field.dart';
import 'social_links_screen.dart';

/// Edit Profile — edit name, username, bio, avatar and cover photos.
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
  late Map<String, String> _socialLinks;
  String? _avatarAsset;
  String? _coverImageAsset;

  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isUsernameAvailable = true;
  final ImagePicker _picker = ImagePicker();

  int get _bioWordCount => _bioCtrl.text
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .length;

  String get _normalizedName => _nameCtrl.text.trim();

  String get _normalizedUsername => _usernameCtrl.text
      .trim()
      .replaceFirst(RegExp(r'^@+'), '')
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase();

  String get _normalizedBio => _bioCtrl.text.trim();

  bool get _isNameValid => _normalizedName.isNotEmpty;

  bool get _isUsernameValid => _normalizedUsername.isNotEmpty;

  bool get _canSave {
    if (!_hasChanges || _isSaving) return false;
    if (!_isNameValid || !_isUsernameValid || !_isUsernameAvailable) return false;
    if (_bioWordCount > 40) return false;
    return true;
  }



  void _handleFieldChanged() {
    _syncHasChanges();
  }

  void _syncHasChanges() {
    final hasChanges =
        _normalizedName != widget.user.displayName.trim() ||
        _normalizedUsername != widget.user.username.trim().toLowerCase() ||
        _normalizedBio != (widget.user.bio ?? '').trim() ||
        _avatarAsset != widget.user.avatarAsset ||
        _coverImageAsset != widget.user.coverImageAsset ||
        !mapEquals(_socialLinks, widget.user.socialLinks);

    if (_hasChanges != hasChanges && mounted) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

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

    if (croppedFile == null) return;

    setState(() {
      _avatarAsset = croppedFile.path;
    });
    _syncHasChanges();
  }

  Future<void> _pickCover(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

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

    if (croppedFile == null) return;

    setState(() {
      _coverImageAsset = croppedFile.path;
    });
    _syncHasChanges();
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
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
          ),
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
                    setState(() {
                      if (isAvatar) {
                        _avatarAsset = null;
                      } else {
                        _coverImageAsset = null;
                      }
                    });
                    _syncHasChanges();
                  },
                ),
              ],
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
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _socialLinks = Map.from(widget.user.socialLinks);
    _avatarAsset = widget.user.avatarAsset;
    _coverImageAsset = widget.user.coverImageAsset;

    for (final ctrl in [_nameCtrl, _usernameCtrl, _bioCtrl]) {
      ctrl.addListener(_handleFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [_nameCtrl, _usernameCtrl, _bioCtrl]) {
      ctrl.removeListener(_handleFieldChanged);
    }
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;

    FocusScope.of(context).unfocus();
    KnockHaptics.impact();
    setState(() => _isSaving = true);

    try {
      final uid = widget.user.id;
      String? finalAvatarUrl = _avatarAsset;
      String? finalCoverUrl = _coverImageAsset;

      // Upload avatar if it's a new local file (not http and not assets/)
      if (_avatarAsset != null &&
          !_avatarAsset!.startsWith('http') &&
          !_avatarAsset!.startsWith('assets/')) {
        finalAvatarUrl = await StorageService.instance.uploadProfilePicture(
          userId: uid,
          file: File(_avatarAsset!),
        );
      }

      // Upload cover if it's a new local file
      if (_coverImageAsset != null &&
          !_coverImageAsset!.startsWith('http') &&
          !_coverImageAsset!.startsWith('assets/')) {
        finalCoverUrl = await StorageService.instance.uploadCoverPicture(
          userId: uid,
          file: File(_coverImageAsset!),
        );
      }

      // Save to Firestore
      await DatabaseService.instance.updateUserProfile(
        uid: uid,
        displayName: _normalizedName,
        username: _normalizedUsername,
        bio: _normalizedBio,
        profileImageUrl: finalAvatarUrl,
        coverImageUrl: finalCoverUrl,
        socialLinks: _socialLinks,
      );

      // Refresh local user cache
      await CurrentUserService.instance.loadCurrentUser();

      final updated = widget.user.copyWith(
        displayName: _normalizedName,
        username: _normalizedUsername,
        bio: _normalizedBio,
        avatarAsset: finalAvatarUrl,
        clearAvatar: finalAvatarUrl == null,
        coverImageAsset: finalCoverUrl,
        clearCover: finalCoverUrl == null,
        socialLinks: _socialLinks,
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
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
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: bg,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close_rounded, size: 22, color: textColor),
                onPressed: _isSaving ? null : () => Navigator.pop(context),
              ),
              centerTitle: true,
              title: Text(
                'Edit Profile',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              actions: const [SizedBox(width: 48)],
            ),
            body: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                    children: [
                      _buildMediaSection(
                        bg: bg,
                        fieldBg: fieldBg,
                        textColor: textColor,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      _FieldLabel('Display Name', subColor),
                      _EditField(
                        controller: _nameCtrl,
                        hint: 'Your name',
                        bg: fieldBg,
                        borderColor: borderColor,
                        textColor: textColor,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('Username', subColor),
                      KnockPostUsernameField(
                        controller: _usernameCtrl,
                        initialUsername: widget.user.username,
                        backgroundColor: fieldBg,
                        borderColor: borderColor,
                        textColor: textColor,
                        onValidityChanged: (isValid) {
                          if (mounted) {
                            setState(() {
                              _isUsernameAvailable = isValid;
                            });
                            _syncHasChanges();
                          }
                        },
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
                                  bottom: 30,
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                              Positioned(
                                bottom: 8,
                                right: 12,
                                child: Text(
                                  '$wordCount/40',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isOver ? Colors.red : subColor,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _FieldLabel('Links', subColor),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          KnockHaptics.selection();
                          final result =
                              await Navigator.push<Map<String, String>>(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => SocialLinksScreen(
                                    initialLinks: _socialLinks,
                                  ),
                                ),
                              );
                          if (result != null) {
                            setState(() {
                              _socialLinks = result;
                            });
                            _syncHasChanges();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 20,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _socialLinks.isEmpty
                                      ? 'Add social links'
                                      : '${_socialLinks.length} link${_socialLinks.length > 1 ? 's' : ''} added',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: _socialLinks.isEmpty
                                        ? textColor.withValues(alpha: 0.35)
                                        : textColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 22,
                                color: textColor.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionBar(
              bg: bg,
              fieldBg: fieldBg,
              textColor: textColor,
              subColor: subColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
          ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }

  Widget _buildMediaSection({
    required Color bg,
    required Color fieldBg,
    required Color textColor,
    required bool isDark,
  }) {
    return SizedBox(
      height: 176,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                          image: _coverImageAsset!.startsWith('http')
                              ? CachedNetworkImageProvider(
                                  (_coverImageAsset == widget.user.coverImageAsset && widget.user.optimizedCoverUrl?.isNotEmpty == true) 
                                      ? widget.user.optimizedCoverUrl! 
                                      : _coverImageAsset!,
                                  cacheManager: KnockpostImageCacheManager.instance,
                                ) as ImageProvider
                              : _coverImageAsset!.startsWith('assets/')
                                  ? AssetImage(_coverImageAsset!) as ImageProvider
                                  : FileImage(File(_coverImageAsset!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
            ),
          ),
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
          Positioned(
            bottom: 0,
            right: 16,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _showImageSourceBottomSheet(isAvatar: true),
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
                          ? (_avatarAsset!.startsWith('http')
                              ? CachedNetworkImageProvider(
                                  (_avatarAsset == widget.user.avatarAsset && widget.user.optimizedAvatarUrl?.isNotEmpty == true) 
                                      ? widget.user.optimizedAvatarUrl! 
                                      : _avatarAsset!,
                                  cacheManager: KnockpostImageCacheManager.instance,
                                )
                              : _avatarAsset!.startsWith('assets/')
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
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showImageSourceBottomSheet(isAvatar: true),
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
    );
  }

  Widget _buildBottomActionBar({
    required Color bg,
    required Color fieldBg,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BottomActionButton(
                      label: 'Cancel',
                      backgroundColor: fieldBg,
                      foregroundColor: textColor,
                      borderColor: borderColor,
                      onTap: _isSaving
                          ? null
                          : () {
                              KnockHaptics.selection();
                              Navigator.pop(context);
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BottomActionButton(
                      label: _isSaving ? 'Saving...' : 'Save',
                      backgroundColor: _canSave
                          ? textColor
                          : textColor.withValues(alpha: isDark ? 0.18 : 0.12),
                      foregroundColor: _canSave ? bg : subColor,
                      borderColor: Colors.transparent,
                      onTap: _canSave ? _save : null,
                    ),
                  ),
                ],
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
          fontWeight: FontWeight.w700,
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
  final EdgeInsetsGeometry? contentPadding;
  final TextCapitalization textCapitalization;

  const _EditField({
    required this.controller,
    required this.hint,
    required this.bg,
    required this.borderColor,
    required this.textColor,
    this.maxLines = 1,
    this.contentPadding,
    this.textCapitalization = TextCapitalization.sentences,
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
        textCapitalization: textCapitalization,
        style: TextStyle(fontSize: 14.5, color: textColor),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: textColor.withValues(alpha: 0.35),
            fontSize: 14.5,
          ),
          contentPadding: contentPadding ??
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _BottomActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
