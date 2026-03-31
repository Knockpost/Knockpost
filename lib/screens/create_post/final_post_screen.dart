import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class FinalPostScreen extends StatefulWidget {
  final List<File> files;

  const FinalPostScreen({super.key, required this.files});

  @override
  State<FinalPostScreen> createState() => _FinalPostScreenState();
}

class _FinalPostScreenState extends State<FinalPostScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  // Media
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  KnockHaptics.tap();
                  //Implement actual posting logic (Firebase)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  "Post",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
              // 📸 MEDIA PREVIEW ROW
              if (widget.files.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          widget.files.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          maxLines: 4,
                          minLines: 1,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: "Write a caption...",
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => caption = val,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
              ),

              // 🎵 MUSIC / AUDIO OPTION
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.music_note_outlined,
                  size: 24,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                title: Text(
                  "Add Music",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                onTap: () {
                  KnockHaptics.tap();
                  //Open music picker or local file picker
                },
              ),

              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
              ),

              // 🎙️ VOICE RECORDING OPTION
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.mic_none_outlined,
                  size: 24,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                title: Text(
                  recordingPath != null
                      ? "Voice Note Recorded"
                      : "Record Voice Note",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: recordingPath != null
                    ? null
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                onTap: isRecording || recordingPath != null
                    ? null
                    : () {
                        KnockHaptics.tap();
                        startRecording();
                      },
              ),

              if (isRecording) _buildRecordingBar(),
              if (!isRecording && recordingPath != null) _buildAudioCard(),

              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
              ),

              // 🌍 AUDIENCE SELECTOR
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.lock_outline,
                  size: 22,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                title: Text(
                  "Audience",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  "Private",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                onTap: () {
                  KnockHaptics.tap();
                },
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
              ),
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
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(18, (i) {
                final height =
                    6.0 +
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
          GestureDetector(
            onTap: () {
              KnockHaptics.tap();
              cancelRecording();
            },
            child: Icon(
              Icons.delete_outline,
              color: Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () {
              KnockHaptics.tap();
              stopRecording();
            },
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Voice message",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(recordingSeconds),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              KnockHaptics.heavy();
              deleteRecording();
            },
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
}
