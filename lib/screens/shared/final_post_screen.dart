import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/audio_lifecycle_manager.dart';
import 'music_editor_screen.dart';
import 'music_picker_screen.dart';
import 'post_settings_sheet.dart';

class FinalPostScreen extends StatefulWidget {
  final List<File> files;
  final String? initialCaption;
  final bool isGlimpse;
  final PostDuration selectedDuration;
  final PostAudience selectedAudience;
  final MusicTrack? initialMusic;
  final int? initialTrimSeconds;
  final int? initialMusicStyle;
  final String? initialMusicCoverUrl;
  final String? initialMusicLyrics;
  final Map<String, dynamic>? initialMusicLyricsConfig;
  final double? initialMusicOverlayX;
  final double? initialMusicOverlayY;
  final double? initialMusicOverlayScale;
  final double? initialMusicOverlayRotation;
  final double? mediaAspectRatio;
  final bool mediaIsBaked;
  final bool isVideoPost;
  final bool videoHasSound;
  final File? coverImageFile;

  final int? initialFilterIndex;
  final List<Map<String, dynamic>>? initialTextOverlays;
  final List<Map<String, dynamic>>? initialDrawPaths;

  const FinalPostScreen({
    super.key,
    required this.files,
    this.initialCaption,
    this.isGlimpse = false,
    this.selectedDuration = PostDuration.h24,
    this.selectedAudience = PostAudience.myFriends,
    this.initialMusic,
    this.initialTrimSeconds,
    this.initialMusicStyle,
    this.initialMusicCoverUrl,
    this.initialMusicLyrics,
    this.initialMusicLyricsConfig,
    this.initialMusicOverlayX,
    this.initialMusicOverlayY,
    this.initialMusicOverlayScale,
    this.initialMusicOverlayRotation,
    this.mediaAspectRatio,
    this.mediaIsBaked = false,
    this.isVideoPost = false,
    this.videoHasSound = false,
    this.coverImageFile,
    this.initialFilterIndex,
    this.initialTextOverlays,
    this.initialDrawPaths,
  });

  @override
  State<FinalPostScreen> createState() => _FinalPostScreenState();
}

class _FinalPostScreenState extends State<FinalPostScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  late TextEditingController _captionController;
  late PostDuration _selectedDuration;
  late PostAudience _selectedAudience;
  MusicTrack? _selectedMusic;
  int? _selectedMusicStyle;
  String? _selectedMusicCoverUrl;
  String? _selectedMusicLyrics;
  Map<String, dynamic>? _selectedMusicLyricsConfig;

  bool isRecording = false;
  String? recordingPath;
  int recordingSeconds = 0;
  Timer? _recordingTimer;

  late AnimationController _pulseController;
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  int _trimStartSeconds = 0;

  @override
  void initState() {
    super.initState();
    AudioLifecycleManager.instance.register(_bgAudioPlayer);
    _captionController = TextEditingController(
      text: widget.initialCaption ?? "",
    );
    _selectedDuration = widget.selectedDuration;
    _selectedAudience = widget.selectedAudience;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _selectedMusic = widget.initialMusic;
    _trimStartSeconds = widget.initialTrimSeconds ?? 0;
    _selectedMusicStyle = widget.initialMusicStyle;
    _selectedMusicCoverUrl = widget.initialMusicCoverUrl;
    _selectedMusicLyrics = widget.initialMusicLyrics;
    _selectedMusicLyricsConfig = widget.initialMusicLyricsConfig;
    if (_selectedMusic != null && !widget.isVideoPost) {
      _playSelectedMusic();
    }
  }

  Future<void> _playSelectedMusic() async {
    if (_selectedMusic == null) {
      await _bgAudioPlayer.stop();
      return;
    }
    try {
      await _bgAudioPlayer.setUrl(_selectedMusic!.previewUrl);
      await _bgAudioPlayer.seek(Duration(seconds: _trimStartSeconds));
      await _bgAudioPlayer.setLoopMode(LoopMode.one);
      await _bgAudioPlayer.play();
    } catch (e) {
      debugPrint('FinalPost bg audio error: $e');
    }
  }

  @override
  void dispose() {
    AudioLifecycleManager.instance.unregister(_bgAudioPlayer);
    _bgAudioPlayer.stop().whenComplete(() => _bgAudioPlayer.dispose());
    _captionController.dispose();
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

  void _postContent() {
    KnockHaptics.tap();

    // ── STOP ALL AUDIO IMMEDIATELY ──
    AudioLifecycleManager.instance.unregister(_bgAudioPlayer);
    _bgAudioPlayer.stop();

    final type = widget.isGlimpse
        ? PostType.waves
        : (widget.files.isEmpty ? PostType.text : PostType.media);

    debugPrint(
      '[_postContent] Creating post: type=$type, files=${widget.files.length}, isGlimpse=${widget.isGlimpse}',
    );
    for (final f in widget.files) {
      debugPrint('[_postContent] File path: ${f.path}');
    }

    final newPost = PostModel(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      authorId: 'me',
      type: type,
      duration: _selectedDuration,
      imagePaths: widget.files.map((f) => f.path).toList(),
      mediaAspectRatio: widget.mediaAspectRatio,
      mediaIsBaked: widget.mediaIsBaked,
      isVideoPost: widget.isVideoPost,
      videoHasSound: widget.videoHasSound,
      coverImagePath: widget.coverImageFile?.path,
      text: _captionController.text.trim(),
      musicUrl: _selectedMusic?.previewUrl,
      musicTitle: _selectedMusic?.title,
      musicArtist: _selectedMusic?.artist,
      musicCoverUrl: _selectedMusicCoverUrl ?? _selectedMusic?.coverUrl,
      musicStyle: _selectedMusicStyle,
      musicLyrics: _selectedMusicLyrics ?? _selectedMusic?.syncedLyrics,
      musicLyricsConfig: _selectedMusicLyricsConfig,
      musicTrimStart: _trimStartSeconds,
      musicOverlayX: widget.initialMusicOverlayX,
      musicOverlayY: widget.initialMusicOverlayY,
      musicOverlayScale: widget.initialMusicOverlayScale,
      musicOverlayRotation: widget.initialMusicOverlayRotation,
      filterIndex: widget.initialFilterIndex,
      textOverlays: widget.initialTextOverlays,
      drawPaths: widget.initialDrawPaths,
      createdAt: DateTime.now(),
      likes: 0,
      views: 0,
    );

    // Add to the front of our global mock list so it shows up in Recents/Profile
    demoOwnPosts.insert(0, newPost);
    debugPrint(
      '[_postContent] demoOwnPosts now has ${demoOwnPosts.length} items',
    );
    demoOwnPostsNotifier.value = List.from(demoOwnPosts);
    debugPrint('[_postContent] Notifier updated. Popping to first route...');

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _editPostSettings() async {
    final result = await showPostSettingsSheet(
      context,
      isGlimpse: widget.isGlimpse,
      initialDuration: _selectedDuration,
      initialAudience: _selectedAudience,
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedDuration = result.duration;
      _selectedAudience = result.audience;
    });
  }

  String _durationLabel(PostDuration d) {
    switch (d) {
      case PostDuration.h24:
        return '24 Hours';
      case PostDuration.h36:
        return '36 Hours';
      case PostDuration.lifetime:
        return 'Lifetime';
    }
  }

  Widget _buildMusicSelectionTile(bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        _selectedMusic != null ? Icons.graphic_eq : Icons.music_note_outlined,
        size: 24,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
      ),
      title: Text(
        _selectedMusic != null ? _selectedMusic!.title : "Add Music",
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _selectedMusic != null
              ? Colors.blue
              : (isDark ? Colors.white : Colors.black),
        ),
      ),
      subtitle: _selectedMusic != null
          ? Text(
              "${_selectedMusic!.artist} • ${_selectedMusic!.duration}",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            )
          : null,
      trailing: _selectedMusic != null
          ? IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () {
                KnockHaptics.tap();
                setState(() {
                  _selectedMusic = null;
                  _selectedMusicStyle = null;
                  _selectedMusicLyrics = null;
                  _selectedMusicLyricsConfig = null;
                  _bgAudioPlayer.stop();
                });
              },
            )
          : Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
      onTap: () async {
        KnockHaptics.tap();
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MusicPickerScreen()),
        );
        if (result != null && result is MusicTrack) {
          if (!mounted) return;
          final isVideo =
              widget.files.isNotEmpty &&
              (widget.files.first.path.toLowerCase().endsWith('.mp4') ||
                  widget.files.first.path.toLowerCase().endsWith('.mov'));

          if (!mounted) return;
          final overlayResult = await Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) =>
                  MusicOverlayScreen(track: result, isVideo: isVideo),
            ),
          );

          if (overlayResult != null && overlayResult is Map) {
            setState(() {
              _selectedMusic = overlayResult['track'] as MusicTrack;
              _trimStartSeconds = overlayResult['trimStartSeconds'] as int;
              _selectedMusicStyle = overlayResult['styleIndex'] as int?;
              _selectedMusicCoverUrl = _selectedMusic?.coverUrl;
              _selectedMusicLyrics = _selectedMusic?.syncedLyrics;
              _selectedMusicLyricsConfig =
                  (overlayResult['lyricsConfig'] as Map?)?.cast<String, dynamic>();
            });
            _playSelectedMusic();
          }
        }
      },
    );
  }

  Widget _buildComposerPreviewThumb(bool isDark) {
    if (widget.isVideoPost) {
      final previewFile = widget.coverImageFile;
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              width: 84,
              height: 112,
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2),
              child: previewFile != null
                  ? Image.file(previewFile, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.videocam_rounded, color: Colors.white),
                    ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.videoHasSound
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.isGlimpse) {
      return Container(
        width: 80,
        height: 120,
        color: Colors.grey.shade800,
        child: const Center(child: Icon(Icons.videocam, color: Colors.white)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        widget.files.first,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.isGlimpse ? "Share Glimpse" : "New Post";

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
          title,
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
                onTap: _postContent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Post",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.files.isNotEmpty) ...[
                      _buildComposerPreviewThumb(isDark),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        maxLines: widget.files.isNotEmpty ? 4 : null,
                        minLines: widget.files.isNotEmpty ? 1 : 4,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: "Write a caption...",
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
              ),

              // ⚙️ POST SETTINGS SUMMARY (Duration + Audience)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _buildSettingChip(
                      icon: Icons.timer_outlined,
                      label: _durationLabel(_selectedDuration),
                      isDark: isDark,
                      onTap: _editPostSettings,
                    ),
                    const SizedBox(width: 10),
                    _buildSettingChip(
                      icon: _selectedAudience.icon,
                      label: _selectedAudience.label,
                      isDark: isDark,
                      onTap: _editPostSettings,
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
              ),

              if (widget.isVideoPost)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Icon(
                    widget.videoHasSound
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 24,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  title: Text(
                    widget.videoHasSound
                        ? "Audio ready"
                        : "Posted without sound",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    widget.videoHasSound
                        ? "Your video audio was finalized in the editor so the export matches the preview."
                        : "This export was finalized without audio in the editor.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                )
              else
                _buildMusicSelectionTile(isDark),

              /*
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Icon(
                    _selectedMusic != null
                        ? Icons.graphic_eq
                        : Icons.music_note_outlined,
                    size: 24,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  title: Text(
                    _selectedMusic != null
                        ? _selectedMusic!.title
                        : "Add Music",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _selectedMusic != null
                          ? Colors.blue
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  subtitle: _selectedMusic != null
                      ? Text(
                          "${_selectedMusic!.artist} • ${_selectedMusic!.duration}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        )
                      : null,
                  trailing: _selectedMusic != null
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            KnockHaptics.tap();
                            setState(() {
                              _selectedMusic = null;
                              _bgAudioPlayer.stop();
                            });
                          },
                        )
                      : Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                  onTap: () async {
                    KnockHaptics.tap();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MusicPickerScreen(),
                      ),
                    );
                    if (result != null && result is MusicTrack) {
                      if (!context.mounted) return;
                      final isVideo =
                          widget.files.isNotEmpty &&
                          (widget.files.first.path.toLowerCase().endsWith(
                                '.mp4',
                              ) ||
                              widget.files.first.path.toLowerCase().endsWith(
                                '.mov',
                              ));

                      if (!context.mounted) return;
                      final overlayResult = await Navigator.push(
                        context,
                        PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (_, __, ___) => MusicOverlayScreen(
                            track: result,
                            isVideo: isVideo,
                          ),
                        ),
                      );

                      if (overlayResult != null && overlayResult is Map) {
                        setState(() {
                          _selectedMusic = overlayResult['track'] as MusicTrack;
                          _trimStartSeconds =
                              overlayResult['trimStartSeconds'] as int;
                          _selectedMusicStyle =
                              overlayResult['styleIndex'] as int?;
                          _selectedMusicCoverUrl = _selectedMusic?.coverUrl;
                          _selectedMusicLyrics = _selectedMusic?.syncedLyrics;
                        });
                        _playSelectedMusic();
                      }
                    }
                  },
                ),

              if (widget.isVideoPost && _selectedMusic != null)
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.grey.shade800
                      : const Color(0xFFEEEEEE),
                ),
              */
              if (widget.isVideoPost && _selectedMusic != null)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.music_note_rounded,
                    size: 24,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  title: Text(
                    _selectedMusic!.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    '${_selectedMusic!.artist} • Included in exported video',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
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

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingChip({
    required IconData icon,
    required String label,
    required bool isDark,
    Color? accentColor,
    VoidCallback? onTap,
  }) {
    final color = accentColor ?? (isDark ? Colors.white70 : Colors.black54);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor != null
              ? accentColor.withValues(alpha: 0.1)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor != null
                ? accentColor.withValues(alpha: 0.35)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, size: 15, color: color),
            ],
          ],
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
                    color: Colors.red.withValues(alpha: 0.5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.play_arrow,
              color: isDark ? Colors.black : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Voice message",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(recordingSeconds),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
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
                color: Colors.red.withValues(alpha: 0.1),
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
