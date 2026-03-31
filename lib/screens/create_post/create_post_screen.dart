import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'media_editor_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ImagePicker _picker = ImagePicker();

  // ─── GALLERY ──────────────────────────────────────────────
  Future<void> _pickGallery() async {
    final List<XFile> files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) {
      if (!mounted) return;
      _navigateToEditor(files.map((e) => File(e.path)).toList());
    }
  }

  // ─── CAMERA ───────────────────────────────────────────────
  Future<void> _capturePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null) {
      if (!mounted) return;
      _navigateToEditor([File(photo.path)]);
    }
  }

  void _navigateToEditor(List<File> files) {
    if (files.isEmpty) return;
    
    // For now, take the first file assuming single photo selection 
    // or carousel/collage will be built upon this later.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaEditorScreen(files: files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Post",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 80,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              "Select Media to Edit",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Choose photos or capture a new one\nto add filters, music, and text.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const Spacer(),
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildButton(
                icon: Icons.photo_library,
                title: "Gallery / Carousel",
                subtitle: "Select one or multiple photos",
                onTap: _pickGallery,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildButton(
                icon: Icons.camera_alt,
                title: "Camera",
                subtitle: "Take a new photo",
                onTap: _capturePhoto,
                isDark: isDark,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xff333333) : const Color(0xffe0e0e0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
