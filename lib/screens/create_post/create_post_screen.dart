import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'media_editor_screen.dart';
import 'post_settings_sheet.dart';
import 'final_post_screen.dart';
import 'glimpse_editor_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final int initialIndex;
  const CreatePostScreen({super.key, this.initialIndex = 0});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ─── POST FLOW (Photos / Text) ───────────────────────────
  Future<void> _pickPhotoGallery() async {
    final List<XFile> files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) {
      if (!mounted) return;
      _navigateToEditor(files.map((e) => File(e.path)).toList());
    }
  }

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaEditorScreen(
          files: files,
          initialCaption: _textController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _goToFinalPostWithoutMedia() async {
    // ⚙️ Settings before posting text
    final settings = await showPostSettingsSheet(context, isGlimpse: false);
    if (settings == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FinalPostScreen(
          files: const [],
          initialCaption: _textController.text.trim(),
          isGlimpse: false,
          selectedDuration: settings.duration,
          selectedAudience: settings.audience,
        ),
      ),
    );
  }

  // ─── GLIMPSE FLOW (Video) ────────────────────────────────
  Future<void> _pickVideoGallery() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 150),
    );
    if (video != null) {
      if (!mounted) return;
      _goToGlimpseEditor(File(video.path));
    }
  }

  Future<void> _recordVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 150),
    );
    if (video != null) {
      if (!mounted) return;
      _goToGlimpseEditor(File(video.path));
    }
  }

  void _goToGlimpseEditor(File videoFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlimpseEditorScreen(
          files: [videoFile],
          initialCaption: _textController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPostMode = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isPostMode ? "New Post" : "New Glimpse",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isPostMode)
            TextButton(
              onPressed: () async {
                KnockHaptics.tap();
                await _goToFinalPostWithoutMedia();
              },
              child: const Text(
                "Next",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? Colors.white : Colors.black,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "POST"),
            Tab(text: "GLIMPSE"),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPostTab(isDark),
            _buildGlimpseTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTab(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _textController,
                  maxLines: null,
                  minLines: 4,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: "What's on your mind?...",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Add a Photo (Optional)",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.photo_library,
                        title: "Gallery",
                        onTap: _pickPhotoGallery,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.camera_alt,
                        title: "Camera",
                        onTap: _capturePhoto,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlimpseTab(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.movie_creation_outlined,
          size: 80,
          color: isDark ? Colors.grey[700] : Colors.grey[300],
        ),
        const SizedBox(height: 24),
        Text(
          "Create a Glimpse",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Share short, engaging videos up to 2 minutes and 30 seconds. Add music and effects.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildListButton(
            icon: Icons.video_library,
            title: "Select from Gallery",
            subtitle: "Browse your device for a video",
            onTap: _pickVideoGallery,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildListButton(
            icon: Icons.videocam,
            title: "Record Video",
            subtitle: "Capture a fresh moment now",
            onTap: _recordVideo,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xff333333) : const Color(0xffe0e0e0),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isDark ? Colors.white : Colors.grey.shade800),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListButton({
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
