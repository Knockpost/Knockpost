import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  // Media
  List<String> mediaFiles = [];
  String caption = "";

  // Voice recording
  bool isRecording = false;
  String? recordingPath;
  int recordingSeconds = 0;
  Timer? _recordingTimer;

  // Pulse animation for recording dot
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ─── GALLERY ──────────────────────────────────────────────
  Future<void> pickMedia() async {
    final List<XFile>? files =
        await _picker.pickMultiImage(imageQuality: 80);
    if (files != null && files.isNotEmpty) {
      setState(() {
        mediaFiles.addAll(files.map((e) => e.path));
      });
    }
  }

  // ─── CAMERA ───────────────────────────────────────────────
  Future<void> capturePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null) {
      setState(() {
        mediaFiles.add(photo.path);
      });
    }
  }

  // ─── VOICE RECORDING ─────────────────────────────────────
  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        isRecording = true;
        recordingSeconds = 0;
        recordingPath = path;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => recordingSeconds++);
      });
    }
  }

  Future<void> stopRecording() async {
    final path = await _recorder.stop();
    _recordingTimer?.cancel();

    setState(() {
      isRecording = false;
      recordingPath = path;
    });
  }

  void cancelRecording() async {
    await _recorder.stop();
    _recordingTimer?.cancel();

    // Delete the temp file
    if (recordingPath != null) {
      final file = File(recordingPath!);
      if (await file.exists()) await file.delete();
    }

    setState(() {
      isRecording = false;
      recordingPath = null;
      recordingSeconds = 0;
    });
  }

  void deleteRecording() async {
    if (recordingPath != null) {
      final file = File(recordingPath!);
      if (await file.exists()) await file.delete();
    }
    setState(() {
      recordingPath = null;
      recordingSeconds = 0;
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          "New Post",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  KnockHaptics.tap();
                  // TODO: handle post
                },
                child: const Text(
                  "Post",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // 🧑 Caption Area
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundImage: AssetImage("assets/test1.jpg"),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        maxLines: null,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        decoration: InputDecoration(
                          hintText: "Write something...",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(top: 10),
                        ),
                        onChanged: (val) => caption = val,
                      ),
                    ),
                  ],
                ),
              ),

              // 🎯 ACTION ICONS (Substack style — below caption)
              Padding(
                padding: const EdgeInsets.only(left: 68, top: 2, bottom: 6),
                child: Row(
                  children: [
                    _icon(Icons.photo_library_outlined, pickMedia),
                    const SizedBox(width: 20),
                    _icon(Icons.camera_alt_outlined, capturePhoto),
                    const SizedBox(width: 20),
                    _icon(
                      Icons.mic_none_outlined,
                      isRecording ? null : startRecording,
                    ),
                  ],
                ),
              ),

              // 🎙️ RECORDING UI
              if (isRecording) _buildRecordingBar(),

              // 🎵 RECORDED AUDIO CARD
              if (!isRecording && recordingPath != null)
                _buildAudioCard(),

              // 📸 MEDIA PREVIEW
              if (mediaFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    itemCount: mediaFiles.length,
                    itemBuilder: (_, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(mediaFiles[i]),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            // Delete button on image
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  KnockHaptics.heavy();
                                  setState(() => mediaFiles.removeAt(i));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            // Page indicator
                            if (mediaFiles.length > 1)
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${i + 1}/${mediaFiles.length}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 🌍 AUDIENCE SELECTOR
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: Icon(Icons.lock_outline,
                    size: 20, color: Colors.grey.shade700),
                title: const Text(
                  "Audience",
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  "Private",
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey.shade400),
                onTap: () { KnockHaptics.tap(); },
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── RECORDING BAR ────────────────────────────────────────
  Widget _buildRecordingBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCCCC), width: 1),
      ),
      child: Row(
        children: [
          // Pulsing red dot
          FadeTransition(
            opacity: _pulseController,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Timer
          Text(
            _formatDuration(recordingSeconds),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(width: 10),

          // Waveform dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(18, (i) {
                final height = 6.0 +
                    (isRecording
                        ? (((i * 7 + recordingSeconds * 3) % 11) * 1.8)
                        : 0.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(width: 10),

          // Cancel
          GestureDetector(
            onTap: () { KnockHaptics.tap(); cancelRecording(); },
            child: Icon(Icons.delete_outline,
                color: Colors.grey.shade600, size: 22),
          ),

          const SizedBox(width: 14),

          // Stop
          GestureDetector(
            onTap: () { KnockHaptics.tap(); stopRecording(); },
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AUDIO ATTACHMENT CARD ────────────────────────────────
  Widget _buildAudioCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Row(
        children: [
          // Play icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
          ),

          const SizedBox(width: 12),

          // Label + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Voice message",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(recordingSeconds),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Delete
          GestureDetector(
            onTap: () { KnockHaptics.heavy(); deleteRecording(); },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ICON BUILDER ─────────────────────────────────────────
  Widget _icon(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap != null ? () { KnockHaptics.tap(); onTap(); } : null,
      child: Icon(
        icon,
        size: 26,
        color: Colors.grey.shade600,
      ),
    );
  }
}
