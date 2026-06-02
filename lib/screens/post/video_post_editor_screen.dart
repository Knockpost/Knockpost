import 'dart:async';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../utils/audio_lifecycle_manager.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/video_post_processing.dart';
import '../../models/media_transform.dart';
import '../../utils/media_transform_utils.dart';
import '../shared/final_post_screen.dart';
import '../shared/music_editor_screen.dart';
import '../shared/music_picker_screen.dart';

enum _VideoEditorTool { trim, music, text, sticker, effects, cover }

class VideoPostEditorScreen extends StatefulWidget {
  final File videoFile;
  final String? initialCaption;
  final bool isGlimpse;

  const VideoPostEditorScreen({
    super.key,
    required this.videoFile,
    this.initialCaption,
    this.isGlimpse = false,
  });

  @override
  State<VideoPostEditorScreen> createState() => _VideoPostEditorScreenState();
}

class _VideoPostEditorScreenState extends State<VideoPostEditorScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _sourceAudioPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  final TextEditingController _textInputController = TextEditingController();
  final Map<VideoPostAspect, MediaTransform> _transforms = {
    for (final aspect in VideoPostAspect.values) aspect: const MediaTransform.identity(),
  };

  final List<_EditableVideoText> _textOverlays = [];
  final List<_EditableSticker> _stickerOverlays = [];
  final List<Color> _textColors = const [
    Colors.white, Colors.black, Color(0xFFFFD54F),
    Color(0xFFFF8A80), Color(0xFF80DEEA), Color(0xFFA5D6A7),
  ];
  final List<String> _stickerEmojis = [
    '🔥','❤️','😂','✨','🥺','🎉','🌟','🎬','🎧','💯','🙌','😎','💀','👀','👍','🙏',
    '💧','💰','🚀','💫','🥰','😜','🤬','🥶','😈','👑','💍','💥','⚡','🔥'
  ];

  late final VideoPlayerController _controller;

  VideoPostSourceInfo? _sourceInfo;
  List<_FrameThumbnail> _frameThumbnails = const [];
  Size _previewFrameSize = const Size(1080, 1350);
  final VideoPostAspect _selectedAspect = VideoPostAspect.portrait;
  _VideoEditorTool _activeTool = _VideoEditorTool.trim;
  VideoPostEffectAdjustments _effects = const VideoPostEffectAdjustments();

  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  Duration _coverTime = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _musicTrimStart = Duration.zero;

  double _gestureBaseScale = 1.0;
  Offset _gestureBaseOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  double _originalAudioVolume = 1.0;
  double _musicVolume = 0.8;

  bool _isLoading = true;
  bool _isExporting = false;
  double? _exportProgress;
  String _exportStatusText = 'Starting export...';
  bool _resumeAfterDrag = false;
  bool _didGenerateThumbnails = false;
  bool _isAddingText = false;
  bool _isLoadingMusic = false;
  bool _isCachingMusic = false;
  bool _isRestartingLoop = false;
  bool _isSyncingPreviewAudio = false;
  bool _queuedPreviewAudioSync = false;
  bool _queuedForcePreviewSeek = false;

  File? _customCoverImage;
  File? _selectedMusicFile;
  MusicTrack? _selectedMusic;
  Map<String, dynamic>? _selectedMusicStickerConfig;
  _EditableVideoText? _selectedTextOverlay;
  _EditableSticker? _selectedStickerOverlay;

  dynamic get _selectedOverlay => _selectedTextOverlay ?? _selectedStickerOverlay;

  Color _draftTextColor = Colors.white;
  VideoPostTextFont _draftTextFont = VideoPostTextFont.classic;

  MediaTransform get _currentTransform => _transforms[_selectedAspect]!;
  Duration get _totalDuration => _sourceInfo?.duration ?? Duration.zero;

  bool get _hasOriginalAudio => _sourceInfo?.hasAudio ?? false;
  bool get _hasAnyAudio => (_hasOriginalAudio && _originalAudioVolume > 0.01) || (_selectedMusic != null && _musicVolume > 0.01);
  bool get _hasPreviewAudio => _hasAnyAudio;

  Size get _sourceSize {
    if (_controller.value.isInitialized && _controller.value.size.width > 0 && _controller.value.size.height > 0) {
      return _controller.value.size;
    }
    return _sourceInfo?.size ?? const Size(1080, 1920);
  }

  @override
  void initState() {
    super.initState();
    AudioLifecycleManager.instance.register(_sourceAudioPlayer);
    AudioLifecycleManager.instance.register(_musicPlayer);
    _controller = VideoPlayerController.file(widget.videoFile, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _controller.addListener(_handleVideoTick);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      final sourceInfo = await VideoPostProcessing.probeSource(
        widget.videoFile,
        fallbackSize: _controller.value.size,
        fallbackDuration: _controller.value.duration,
      );

      final duration = sourceInfo.duration > Duration.zero ? sourceInfo.duration : _controller.value.duration;
      final coverTime = duration > const Duration(seconds: 1) ? const Duration(seconds: 1) : Duration.zero;

      if (sourceInfo.hasAudio) {
        await _sourceAudioPlayer.stop();
        await _sourceAudioPlayer.setFilePath(widget.videoFile.path);
        await _sourceAudioPlayer.setVolume(_originalAudioVolume);
      } else {
        await _sourceAudioPlayer.stop();
      }

      await _controller.setLooping(false);
      await _controller.seekTo(Duration.zero);
      await _controller.setVolume(0);
      await _controller.play();

      if (!mounted) return;
      setState(() {
        _sourceInfo = sourceInfo;
        _trimStart = Duration.zero;
        _trimEnd = duration;
        _coverTime = coverTime;
        _playbackPosition = Duration.zero;
        _originalAudioVolume = sourceInfo.hasAudio ? 1.0 : 0.0;
        _isLoading = false;
      });

      await _schedulePreviewAudioSync(forceSeek: true);
      _generateFrameThumbnails();
    } catch (error) {
      debugPrint('Video editor init error: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load this video. Please pick another one.')),
      );
    }
  }

  Future<void> _generateFrameThumbnails() async {
    if (_didGenerateThumbnails) return;
    _didGenerateThumbnails = true;

    final totalMs = max(_totalDuration.inMilliseconds, 1);
    const sampleCount = 8;
    try {
      final List<_FrameThumbnail> thumbnails = [];
      for (int i = 0; i < sampleCount; i++) {
        if (!mounted) return;
        final ratio = sampleCount == 1 ? 0.0 : i / (sampleCount - 1);
        final timeMs = (totalMs * ratio).round();
        final bytes = await VideoThumbnail.thumbnailData(
          video: widget.videoFile.path, imageFormat: ImageFormat.JPEG,
          maxWidth: 240, quality: 60, timeMs: timeMs,
        );
        if (bytes != null) {
          thumbnails.add(_FrameThumbnail(time: Duration(milliseconds: timeMs), bytes: bytes));
        }
        if (mounted) setState(() => _frameThumbnails = List.from(thumbnails));
      }
    } catch (error) {
      debugPrint('Video thumbnail generation error: $error');
    }
  }

  void _handleVideoTick() {
    if (!_controller.value.isInitialized || !mounted) return;

    final position = _controller.value.position;
    if (_controller.value.isPlaying && position >= _trimEnd) {
      unawaited(_restartTrimLoop());
      return;
    }

    if ((position.inMilliseconds - _playbackPosition.inMilliseconds).abs() >= 48) {
      setState(() => _playbackPosition = position);
    }

    if (_hasPreviewAudio) unawaited(_schedulePreviewAudioSync());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleVideoTick);
    _controller.dispose();
    _textInputController.dispose();
    AudioLifecycleManager.instance.unregister(_sourceAudioPlayer);
    AudioLifecycleManager.instance.unregister(_musicPlayer);
    _sourceAudioPlayer.stop().whenComplete(() => _sourceAudioPlayer.dispose());
    _musicPlayer.stop().whenComplete(() => _musicPlayer.dispose());
    super.dispose();
  }

  Future<void> _pausePreviewAudio() async {
    await _sourceAudioPlayer.pause();
    await _musicPlayer.pause();
  }

  Future<void> _restartTrimLoop() async {
    if (_isRestartingLoop) return;
    _isRestartingLoop = true;
    try {
      await _controller.seekTo(_trimStart);
      if (!mounted) return;
      setState(() => _playbackPosition = _trimStart);
      await _controller.play();
      await _schedulePreviewAudioSync(forceSeek: true);
    } finally {
      _isRestartingLoop = false;
    }
  }

  Future<void> _schedulePreviewAudioSync({bool forceSeek = false}) async {
    _queuedForcePreviewSeek = _queuedForcePreviewSeek || forceSeek;
    if (_isSyncingPreviewAudio) {
      _queuedPreviewAudioSync = true;
      return;
    }

    do {
      _isSyncingPreviewAudio = true;
      final shouldForceSeek = _queuedForcePreviewSeek;
      _queuedForcePreviewSeek = false;
      _queuedPreviewAudioSync = false;

      try {
        await _syncOriginalAudioToVideo(forceSeek: shouldForceSeek);
        await _syncMusicToVideo(forceSeek: shouldForceSeek);
      } finally {
        _isSyncingPreviewAudio = false;
      }
    } while (mounted && (_queuedPreviewAudioSync || _queuedForcePreviewSeek));
  }

  Future<void> _syncOriginalAudioToVideo({bool forceSeek = false}) async {
    if (!_hasOriginalAudio) {
      await _sourceAudioPlayer.pause();
      return;
    }

    final clipPosition = _clampDuration(_playbackPosition, Duration.zero, _totalDuration > Duration.zero ? _totalDuration : _playbackPosition);
    final delta = (_sourceAudioPlayer.position.inMilliseconds - clipPosition.inMilliseconds).abs();

    if (forceSeek || delta > 220) await _sourceAudioPlayer.seek(clipPosition);
    await _sourceAudioPlayer.setVolume(_originalAudioVolume);
    
    if (_controller.value.isPlaying && _originalAudioVolume > 0.01) {
      if (!_sourceAudioPlayer.playing) await _sourceAudioPlayer.play();
    } else if (_sourceAudioPlayer.playing) {
      await _sourceAudioPlayer.pause();
    }
  }

  Future<void> _syncMusicToVideo({bool forceSeek = false}) async {
    if (_selectedMusic == null) {
      await _musicPlayer.pause();
      return;
    }

    final duration = _musicPlayer.duration;
    if (duration == null || duration <= Duration.zero) return;

    final relativeMs = max(0, _playbackPosition.inMilliseconds - _trimStart.inMilliseconds);
    final totalMusicMs = max(duration.inMilliseconds, 1);
    final desiredMs = ((_musicTrimStart.inMilliseconds + relativeMs) % totalMusicMs).toInt();
    final desiredPosition = Duration(milliseconds: desiredMs);
    final delta = (_musicPlayer.position.inMilliseconds - desiredMs).abs();

    if (forceSeek || delta > 420) await _musicPlayer.seek(desiredPosition);
    await _musicPlayer.setVolume(_musicVolume);

    if (_controller.value.isPlaying && _musicVolume > 0.01) {
      if (!_musicPlayer.playing) await _musicPlayer.play();
    } else if (_musicPlayer.playing) {
      await _musicPlayer.pause();
    }
  }

  void _setTool(_VideoEditorTool tool) {
    if (_activeTool == tool) return;
    KnockHaptics.tap();
    setState(() {
      _activeTool = tool;
      _selectedTextOverlay = null;
      _selectedStickerOverlay = null;
    });
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) return;
    KnockHaptics.tap();
    if (_controller.value.isPlaying) {
      await _controller.pause();
      await _pausePreviewAudio();
    } else {
      if (_playbackPosition >= _trimEnd) {
        await _controller.seekTo(_trimStart);
        setState(() => _playbackPosition = _trimStart);
      }
      await _controller.play();
      await _schedulePreviewAudioSync(forceSeek: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _seekTo(Duration position) async {
    if (!_controller.value.isInitialized) return;
    final clamped = _clampDuration(position, _trimStart, _trimEnd);
    await _controller.seekTo(clamped);
    if (!mounted) return;
    setState(() => _playbackPosition = clamped);
    await _schedulePreviewAudioSync(forceSeek: true);
  }

  void _pauseForDrag() {
    _resumeAfterDrag = _controller.value.isPlaying;
    if (_resumeAfterDrag) {
      _controller.pause();
      unawaited(_pausePreviewAudio());
    }
  }

  void _resumeAfterInteraction() {
    if (_resumeAfterDrag) {
      _resumeAfterDrag = false;
      _controller.play();
      unawaited(_schedulePreviewAudioSync(forceSeek: true));
    }
  }

  Future<void> _resetCurrentTransform() async {
    KnockHaptics.tap();
    setState(() => _transforms[_selectedAspect] = const MediaTransform.identity());
  }

  Future<void> _setOriginalAudioVolume(double value) async {
    if (!_hasOriginalAudio) return;
    setState(() => _originalAudioVolume = value);
    await _sourceAudioPlayer.setVolume(value);
    await _schedulePreviewAudioSync();
  }

  Future<void> _setMusicVolume(double value) async {
    setState(() => _musicVolume = value);
    await _musicPlayer.setVolume(value);
    await _schedulePreviewAudioSync();
  }

  Future<void> _pickCustomCoverImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image == null || !mounted) return;
    KnockHaptics.tap();
    setState(() {
      _customCoverImage = File(image.path);
      _coverTime = _clampDuration(_playbackPosition, _trimStart, _trimEnd);
    });
  }

  void _selectCoverTime(Duration time) {
    KnockHaptics.tap();
    setState(() {
      _customCoverImage = null;
      _coverTime = _clampDuration(time, _trimStart, _trimEnd);
    });
  }

  Future<void> _pickMusic() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPickerScreen()));
    if (result == null || result is! MusicTrack || !mounted) return;

    final overlayResult = await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => MusicOverlayScreen(track: result, isVideo: true),
      ),
    );

    if (overlayResult == null || overlayResult is! Map || !mounted) return;

    setState(() {
      _selectedMusic = overlayResult['track'] as MusicTrack;
      _selectedMusicFile = null;
      _musicTrimStart = Duration(seconds: overlayResult['trimStartSeconds'] as int);
      
      final double musicDurSec = overlayResult['trimDurationSeconds'] as double? ?? 15.0;
      final desiredVideoDuration = Duration(milliseconds: (musicDurSec * 1000).round());
      
      if (_totalDuration > desiredVideoDuration) {
        final newTrimEnd = _trimStart + desiredVideoDuration;
        if (newTrimEnd <= _totalDuration) {
          _trimEnd = newTrimEnd;
        } else {
          _trimEnd = _totalDuration;
          _trimStart = _trimEnd - desiredVideoDuration;
          if (_trimStart < Duration.zero) _trimStart = Duration.zero;
        }
      }

      _musicVolume = overlayResult['musicVolume'] as double? ?? 1.0;
      _originalAudioVolume = overlayResult['originalVolume'] as double? ?? _originalAudioVolume;
      _isLoadingMusic = true;
      
      _selectedMusicStickerConfig = (overlayResult['stickerConfig'] as Map?)?.cast<String, dynamic>();
    });
    
    await _sourceAudioPlayer.setVolume(_originalAudioVolume);

    try {
      await _musicPlayer.stop();
      await _musicPlayer.setUrl(_selectedMusic!.previewUrl);
      await _musicPlayer.setVolume(_musicVolume);
      await _schedulePreviewAudioSync(forceSeek: true);
      if (mounted) setState(() => _isLoadingMusic = false);
      unawaited(_cacheMusicPreview(result));
    } catch (error) {
      if (!mounted) return;
      setState(() { 
        _isLoadingMusic = false; 
        _selectedMusic = null; 
        _selectedMusicStickerConfig = null; 
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load this song.')));
    }
  }

  Future<void> _cacheMusicPreview(MusicTrack track) async {
    if (_selectedMusic?.previewUrl != track.previewUrl) return;
    setState(() => _isCachingMusic = true);

    try {
      final tempDir = Directory.systemTemp;
      final outputFile = File('${tempDir.path}\\knockpost_music_${track.previewUrl.hashCode.abs()}.m4a');
      if (!outputFile.existsSync()) {
        final response = await http.get(Uri.parse(track.previewUrl));
        if (response.statusCode == 200) await outputFile.writeAsBytes(response.bodyBytes);
      }
      if (!mounted || _selectedMusic?.previewUrl != track.previewUrl) return;
      setState(() => _selectedMusicFile = outputFile);
    } catch (error) {
      debugPrint('Music cache error: $error');
    } finally {
      if (mounted && _selectedMusic?.previewUrl == track.previewUrl) setState(() => _isCachingMusic = false);
    }
  }

  Future<File?> _ensureMusicFileForExport() async {
    final track = _selectedMusic;
    if (track == null || _musicVolume <= 0.01) return null;
    if (_selectedMusicFile != null && _selectedMusicFile!.existsSync()) return _selectedMusicFile;

    try {
      final tempDir = Directory.systemTemp;
      // Use the exact same name as the background cache so it reuses it instantly
      final outputFile = File('${tempDir.path}\\knockpost_music_${track.previewUrl.hashCode.abs()}.m4a');
      if (!outputFile.existsSync()) {
        final response = await http.get(Uri.parse(track.previewUrl));
        if (response.statusCode == 200) await outputFile.writeAsBytes(response.bodyBytes);
      }
      _selectedMusicFile = outputFile;
      return outputFile;
    } catch (error) {
      return null;
    }
  }

  Future<void> _removeMusic() async {
    if (_selectedMusic == null) return;
    KnockHaptics.tap();
    await _musicPlayer.stop();
    if (!mounted) return;
    setState(() {
      _selectedMusic = null;
      _selectedMusicFile = null;
      _selectedMusicStickerConfig = null;
      _musicTrimStart = Duration.zero;
      _musicVolume = 0.0;
      _isLoadingMusic = false;
      _isCachingMusic = false;
    });
  }

  void _startAddingText() {
    KnockHaptics.tap();
    setState(() {
      _isAddingText = true;
      _selectedTextOverlay = null;
      _selectedStickerOverlay = null;
      _draftTextColor = Colors.white;
      _draftTextFont = VideoPostTextFont.classic;
    });
    _textInputController.clear();
  }

  void _addTextOverlay() {
    final text = _textInputController.text.trim();
    if (text.isEmpty) return;
    final overlay = _EditableVideoText(
      text: text, x: 0.12, y: 0.3,
      color: _draftTextColor, font: _draftTextFont,
      startTime: _trimStart, endTime: _trimEnd,
    );
    setState(() {
      _textOverlays.add(overlay);
      _selectedTextOverlay = overlay;
      _isAddingText = false;
      _activeTool = _VideoEditorTool.text;
    });
  }

  void _addStickerOverlay(String emoji) {
    KnockHaptics.tap();
    final overlay = _EditableSticker(
      emoji: emoji, x: 0.3, y: 0.4,
      startTime: _trimStart, endTime: _trimEnd,
    );
    setState(() {
      _stickerOverlays.add(overlay);
      _selectedStickerOverlay = overlay;
      _selectedTextOverlay = null;
    });
  }

  void _deleteSelectedOverlay() {
    KnockHaptics.tap();
    setState(() {
      if (_selectedTextOverlay != null) {
        _textOverlays.remove(_selectedTextOverlay);
        _selectedTextOverlay = null;
      }
      if (_selectedStickerOverlay != null) {
        _stickerOverlays.remove(_selectedStickerOverlay);
        _selectedStickerOverlay = null;
      }
    });
  }

  Future<void> _exportAndContinue() async {
    if (_isExporting || _isLoading || _sourceInfo == null) return;
    setState(() {
      _isExporting = true;
      _exportProgress = null;
      _exportStatusText = 'Preparing audio track...';
    });
    await _controller.pause();
    await _pausePreviewAudio();

    try {
      final musicFile = await _ensureMusicFileForExport().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Music download took too long'),
      );
      if (_selectedMusic != null && _musicVolume > 0.01 && musicFile == null) {
        if (mounted) setState(() => _isExporting = false);
        return;
      }

      if (mounted) {
        setState(() {
          _exportStatusText = 'Processing video and music...';
          _exportProgress = 0.0;
        });
      }

      final result = await VideoPostProcessing.exportEditedVideo(
        VideoPostExportRequest(
          inputVideo: widget.videoFile,
          sourceSize: _sourceSize,
          previewFrameSize: _previewFrameSize,
          outputSize: _selectedAspect.outputSize,
          transform: _currentTransform,
          trimStart: _trimStart,
          trimEnd: _trimEnd,
          coverTime: _coverTime,
          sourceHasAudio: _hasOriginalAudio,
          originalAudioVolume: _originalAudioVolume,
          musicFile: musicFile,
          musicTrimStart: _musicTrimStart,
          musicVolume: _musicVolume,
          customCoverImage: _customCoverImage,
          textOverlays: _textOverlays.map((o) => o.toProcessingOverlay()).toList(),
          stickerOverlays: _stickerOverlays.map((o) => o.toProcessingOverlay()).toList(),
          effectAdjustments: _effects,
        ),
        onProgress: (prog) {
          if (mounted) setState(() => _exportProgress = prog);
        },
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FinalPostScreen(
            files: [result.videoFile],
            initialCaption: widget.initialCaption,
            isGlimpse: widget.isGlimpse,
            mediaAspectRatio: _selectedAspect.ratio,
            mediaIsBaked: true,
            isVideoPost: true,
            videoHasSound: _hasAnyAudio,
            coverImageFile: result.coverFile,
            initialMusic: _selectedMusic,
            initialTrimSeconds: _musicTrimStart.inSeconds,
            initialMusicStickerConfig: _selectedMusicStickerConfig,
            initialMusicVolume: _musicVolume,
            initialOriginalAudioVolume: _originalAudioVolume,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Video export error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not process the video.')));
      await _controller.seekTo(_trimStart);
      await _controller.play();
      await _schedulePreviewAudioSync(forceSeek: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Duration _clampDuration(Duration value, Duration minValue, Duration maxValue) {
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: AspectRatio(aspectRatio: _selectedAspect.ratio, child: _buildPreviewSurface()),
                      ),
                    ),
                  ),
                  if (_selectedOverlay != null) 
                    _buildOverlayTimelineEditor()
                  else ...[
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildToolSheet()),
                    const SizedBox(height: 12),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildBottomBar()),
                    const SizedBox(height: 12),
                  ]
                ],
              ),
              if (_isAddingText) _buildTextComposerOverlay(),
              if (_isExporting) _buildExportOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
          const Expanded(child: Center(child: Text('REELS STUDIO', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.4)))),
          TextButton(
            onPressed: (_isExporting || _isLoading) ? null : _exportAndContinue,
            style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: _isExporting ? const SizedBox(width: 18, height: 18, child: KnockPostLoadingIndicator()) : const Text('Next', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPreviewSurface() {
    if (_isLoading || !_controller.value.isInitialized || _sourceInfo == null) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(color: Colors.black, child: const Center(child: KnockPostLoadingIndicator())));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final frameSize = Size(constraints.maxWidth, constraints.maxHeight);
        _previewFrameSize = frameSize;

        final transform = _currentTransform.copyWith(
          containerWidth: frameSize.width,
          containerHeight: frameSize.height,
        );

        final drawRect = MediaTransformUtils.buildDrawRect(
          canvasSize: frameSize, 
          mediaSize: _sourceSize, 
          transform: transform
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_selectedOverlay != null) {
                setState(() { _selectedTextOverlay = null; _selectedStickerOverlay = null; });
                return;
              }
              _togglePlayback();
            },
            onDoubleTap: _resetCurrentTransform,
            onScaleStart: (details) {
              _gestureBaseScale = transform.scale;
              _gestureBaseOffset = Offset(transform.translateX, transform.translateY);
              _gestureStartFocal = details.focalPoint;
            },
            onScaleUpdate: (details) {
              final newScale = MediaTransformUtils.clampScale(_gestureBaseScale * details.scale);
              final proposedOffset = _gestureBaseOffset + (details.focalPoint - _gestureStartFocal);
              
              final clampedOffset = MediaTransformUtils.clampOffset(
                proposed: proposedOffset, 
                scale: newScale, 
                mediaSize: _sourceSize, 
                canvasSize: frameSize
              );
              
              setState(() {
                _transforms[_selectedAspect] = transform.copyWith(
                  scale: newScale,
                  translateX: clampedOffset.dx,
                  translateY: clampedOffset.dy,
                );
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Positioned.fromRect(
                  rect: drawRect,
                  child: _effects.isIdentity 
                    ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _sourceSize.width, height: _sourceSize.height, child: VideoPlayer(_controller)))
                    : ColorFiltered(
                        colorFilter: _getColorFilterMatrix(),
                        child: FittedBox(fit: BoxFit.fill, child: SizedBox(width: _sourceSize.width, height: _sourceSize.height, child: VideoPlayer(_controller))),
                      ),
                ),
                
                // Cinematic grain / glow simple UI representation
                if (_effects.filter == CinematicEffect.grain)
                  Container(color: Colors.black.withValues(alpha: 0.05)),
                if (_effects.filter == CinematicEffect.glow)
                  BackdropFilter(filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5), child: Container(color: Colors.transparent)),
                if (_effects.filter == CinematicEffect.blur)
                  BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent)),
                  
                if (_selectedMusic != null && _selectedMusicStickerConfig != null)
                  RepaintBoundary(
                    child: MusicStickerWidget(
                      title: _selectedMusic!.title,
                      artist: _selectedMusic!.artist,
                      coverUrl: _selectedMusic!.coverUrl,
                      configData: _selectedMusicStickerConfig,
                      isPlaying: _controller.value.isPlaying,
                      isEditable: true,
                      onConfigChanged: (config) {
                        setState(() {
                          _selectedMusicStickerConfig = config.toMap();
                        });
                      },
                    ),
                  ),
                ..._textOverlays.map((o) => _buildPreviewTextOverlay(o, frameSize)),
                ..._stickerOverlays.map((o) => _buildPreviewStickerOverlay(o, frameSize)),
                
                Positioned(top: 12, right: 12, child: _previewCircleButton(icon: _hasAnyAudio ? Icons.volume_up_rounded : Icons.volume_off_rounded, onTap: () {})),
                if (!_controller.value.isPlaying) Center(child: Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.15))), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32))),
              ],
            ),
          ),
        );
      },
    );
  }

  ColorFilter _getColorFilterMatrix() {
    switch (_effects.filter) {
      case CinematicEffect.warm: return const ColorFilter.matrix([1.15,0,0,0,0, 0,1.0,0,0,0, 0,0,0.85,0,0, 0,0,0,1,0]);
      case CinematicEffect.cool: return const ColorFilter.matrix([0.85,0,0,0,0, 0,1.0,0,0,0, 0,0,1.15,0,0, 0,0,0,1,0]);
      case CinematicEffect.vintage: return const ColorFilter.matrix([1.2,0.1,0,0,0, 0,1.1,0,0,0, 0,0,0.8,0,0, 0,0,0,1,0]);
      default: return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }

  bool _isOverlayVisible(dynamic o) {
    final start = o.startTime ?? _trimStart;
    final end = o.endTime ?? _trimEnd;
    return _playbackPosition >= start && _playbackPosition <= end;
  }

  Widget _buildPreviewTextOverlay(_EditableVideoText overlay, Size frameSize) {
    if (!_isOverlayVisible(overlay)) return const SizedBox();
    final isSelected = identical(_selectedTextOverlay, overlay);

    return Positioned(
      left: overlay.x * frameSize.width,
      top: overlay.y * frameSize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() { _selectedTextOverlay = overlay; _selectedStickerOverlay = null; }),
        onScaleStart: (details) {
          overlay.gestureBaseScale = overlay.scale;
          overlay.gestureBaseRotation = overlay.rotation;
          overlay.gestureStartFocal = details.focalPoint;
          overlay.gestureStartPosition = Offset(overlay.x, overlay.y);
          setState(() { _selectedTextOverlay = overlay; _selectedStickerOverlay = null; });
        },
        onScaleUpdate: (details) {
          final delta = details.focalPoint - overlay.gestureStartFocal;
          overlay.scale = (overlay.gestureBaseScale * details.scale).clamp(0.4, 4.2);
          if (details.pointerCount > 1) overlay.rotation = overlay.gestureBaseRotation + details.rotation;
          overlay.x = overlay.gestureStartPosition.dx + delta.dx / frameSize.width;
          overlay.y = overlay.gestureStartPosition.dy + delta.dy / frameSize.height;
          setState(() {});
        },
        child: Transform.rotate(
          angle: overlay.rotation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: isSelected ? BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.6))) : null,
            child: Text(overlay.text, maxLines: 3, style: VideoPostProcessing.buildTextStyle(overlay: overlay.toProcessingOverlay(), frameSize: frameSize)),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewStickerOverlay(_EditableSticker overlay, Size frameSize) {
    if (!_isOverlayVisible(overlay)) return const SizedBox();
    final isSelected = identical(_selectedStickerOverlay, overlay);

    return Positioned(
      left: overlay.x * frameSize.width,
      top: overlay.y * frameSize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() { _selectedStickerOverlay = overlay; _selectedTextOverlay = null; }),
        onScaleStart: (details) {
          overlay.gestureBaseScale = overlay.scale;
          overlay.gestureBaseRotation = overlay.rotation;
          overlay.gestureStartFocal = details.focalPoint;
          overlay.gestureStartPosition = Offset(overlay.x, overlay.y);
          setState(() { _selectedStickerOverlay = overlay; _selectedTextOverlay = null; });
        },
        onScaleUpdate: (details) {
          final delta = details.focalPoint - overlay.gestureStartFocal;
          overlay.scale = (overlay.gestureBaseScale * details.scale).clamp(0.4, 4.2);
          if (details.pointerCount > 1) overlay.rotation = overlay.gestureBaseRotation + details.rotation;
          overlay.x = overlay.gestureStartPosition.dx + delta.dx / frameSize.width;
          overlay.y = overlay.gestureStartPosition.dy + delta.dy / frameSize.height;
          setState(() {});
        },
        child: Transform.rotate(
          angle: overlay.rotation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: isSelected ? BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.6))) : null,
            child: Text(overlay.emoji, style: TextStyle(fontSize: max(32.0, frameSize.width * 0.15) * overlay.scale, shadows: const [Shadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))])),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _toolButton(icon: Icons.content_cut_rounded, label: 'Trim', tool: _VideoEditorTool.trim), const SizedBox(width: 12),
                _toolButton(icon: _selectedMusic != null ? Icons.graphic_eq_rounded : Icons.music_note_rounded, label: 'Music', tool: _VideoEditorTool.music), const SizedBox(width: 12),
                _toolButton(icon: Icons.text_fields_rounded, label: 'Text', tool: _VideoEditorTool.text), const SizedBox(width: 12),
                _toolButton(icon: Icons.emoji_emotions_rounded, label: 'Sticker', tool: _VideoEditorTool.sticker), const SizedBox(width: 12),
                _toolButton(icon: Icons.auto_awesome_rounded, label: 'Effects', tool: _VideoEditorTool.effects), const SizedBox(width: 12),
                _toolButton(icon: Icons.photo_size_select_large_rounded, label: 'Cover', tool: _VideoEditorTool.cover),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolSheet() {
    Widget child;
    switch (_activeTool) {
      case _VideoEditorTool.trim: child = _buildTrimSheet(); break;
      case _VideoEditorTool.music: child = _buildMusicSheet(); break;
      case _VideoEditorTool.text: child = _buildTextSheet(); break;
      case _VideoEditorTool.sticker: child = _buildStickerSheet(); break;
      case _VideoEditorTool.effects: child = _buildEffectsSheet(); break;
      case _VideoEditorTool.cover: child = _buildCoverSheet(); break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey(_activeTool), child: child)),
        ),
      ),
    );
  }

  Widget _buildTrimSheet() {
    final maxMs = max(_totalDuration.inMilliseconds.toDouble(), 1.0);
    final rangeValues = RangeValues(_trimStart.inMilliseconds.toDouble().clamp(0.0, maxMs), _trimEnd.inMilliseconds.toDouble().clamp(0.0, maxMs));
    final currentMs = _clampDuration(_playbackPosition, _trimStart, _trimEnd).inMilliseconds.toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeader(title: 'Trim', subtitle: 'Pick the start and end of the clip you want to post.'),
        const SizedBox(height: 14),
        _buildFilmstrip(),
        const SizedBox(height: 14),
        SliderTheme(
          data: _sliderTheme().copyWith(rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8), thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0)),
          child: RangeSlider(
            values: rangeValues, min: 0, max: maxMs,
            onChangeStart: (_) => _pauseForDrag(),
            onChanged: (values) {
              final start = Duration(milliseconds: values.start.round());
              final end = Duration(milliseconds: max(values.end.round(), values.start.round() + 500));
              setState(() { _trimStart = start; _trimEnd = end > _totalDuration ? _totalDuration : end; });
              if (_playbackPosition < _trimStart || _playbackPosition > _trimEnd) _seekTo(_trimStart);
            },
            onChangeEnd: (_) => _resumeAfterInteraction(),
          ),
        ),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            min: _trimStart.inMilliseconds.toDouble(), max: max(_trimEnd.inMilliseconds.toDouble(), 1.0),
            value: currentMs.clamp(_trimStart.inMilliseconds.toDouble(), max(_trimEnd.inMilliseconds.toDouble(), 1.0)),
            onChangeStart: (_) => _pauseForDrag(),
            onChanged: (value) => _seekTo(Duration(milliseconds: value.round())),
            onChangeEnd: (_) => _resumeAfterInteraction(),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayTimelineEditor() {
    final o = _selectedOverlay;
    if (o == null) return const SizedBox();

    final maxMs = max(_totalDuration.inMilliseconds.toDouble(), 1.0);
    final startVal = (o.startTime ?? _trimStart).inMilliseconds.toDouble().clamp(0.0, maxMs);
    final endVal = (o.endTime ?? _trimEnd).inMilliseconds.toDouble().clamp(0.0, maxMs);
    final rangeValues = RangeValues(min(startVal, endVal), max(startVal, endVal));
    final currentMs = _clampDuration(_playbackPosition, Duration.zero, _totalDuration).inMilliseconds.toDouble();

    return Container(
       padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
       margin: const EdgeInsets.symmetric(horizontal: 12),
       decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Set duration', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                GestureDetector(onTap: () => setState((){ _selectedTextOverlay = null; _selectedStickerOverlay = null;}), child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22))
              ],
            ),
            const SizedBox(height: 12),
            _buildFilmstrip(),
            const SizedBox(height: 12),
            SliderTheme(
              data: _sliderTheme().copyWith(activeTrackColor: Colors.yellow, thumbColor: Colors.yellow, overlayColor: Colors.yellow.withValues(alpha: 0.1)),
              child: RangeSlider(
                values: rangeValues, min: 0, max: maxMs,
                onChangeStart: (_) => _pauseForDrag(),
                onChanged: (values) {
                  final start = Duration(milliseconds: values.start.round());
                  final end = Duration(milliseconds: values.end.round());
                  setState(() { o.startTime = start; o.endTime = end; });
                  if (_playbackPosition < start || _playbackPosition > end) _seekTo(start);
                },
                onChangeEnd: (_) => _resumeAfterInteraction(),
              ),
            ),
            SliderTheme(
              data: _sliderTheme(),
              child: Slider(
                min: 0, max: maxMs, value: currentMs,
                onChangeStart: (_) => _pauseForDrag(),
                onChanged: (value) => _seekTo(Duration(milliseconds: value.round())),
                onChangeEnd: (_) => _resumeAfterInteraction(),
              ),
            ),
         ]
       ),
    );
  }

  Widget _buildStickerSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
             _sheetHeader(title: 'Stickers', subtitle: 'Add emojis to your post.'),
             const Spacer(),
             if (_selectedStickerOverlay != null)
                _secondaryAction(icon: Icons.delete_outline, label: 'Remove', onTap: _deleteSelectedOverlay)
          ]
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: _stickerEmojis.length,
          itemBuilder: (context, index) {
            final emoji = _stickerEmojis[index];
            return GestureDetector(
              onTap: () => _addStickerOverlay(emoji),
              child: Container(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
              ),
            );
          },
        )
      ],
    );
  }

  Widget _buildMusicSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeader(title: 'Music', subtitle: 'Sync music and display automated lyrics.'),
        const SizedBox(height: 14),
        if (_selectedMusic == null) GestureDetector(onTap: _pickMusic, child: _actionCard(icon: Icons.music_note_rounded, title: 'Add Music', subtitle: 'Browse and search songs.'))
        else ...[
          _selectedTrackCard(),
          const SizedBox(height: 12),
          Row(children: [ Expanded(child: _secondaryAction(icon: Icons.search_rounded, label: 'Change', onTap: _pickMusic)), const SizedBox(width: 10), Expanded(child: _secondaryAction(icon: Icons.close_rounded, label: 'Remove', onTap: _removeMusic)) ]),
          const SizedBox(height: 16),
          _volumeRow(label: 'Original', icon: Icons.volume_up_rounded, value: _originalAudioVolume, enabled: _hasOriginalAudio, onChanged: _hasOriginalAudio ? _setOriginalAudioVolume : null),
          const SizedBox(height: 12),
          _volumeRow(label: 'Music', icon: Icons.graphic_eq_rounded, value: _musicVolume, enabled: true, onChanged: _setMusicVolume),
        ],
      ],
    );
  }

  Widget _buildTextSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeader(title: 'Text', subtitle: 'Add text, drag, and pinch.'),
        const SizedBox(height: 14),
        Row(children: [ Expanded(child: _secondaryAction(icon: Icons.add_rounded, label: 'Add Text', onTap: _startAddingText)), const SizedBox(width: 10), Expanded(child: _secondaryAction(icon: Icons.delete_outline_rounded, label: 'Remove', onTap: _selectedTextOverlay != null ? _deleteSelectedOverlay : null)) ]),
        const SizedBox(height: 16),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: VideoPostTextFont.values.map((font) => Padding(padding: const EdgeInsets.only(right: 10), child: _fontChip(font: font, selected: (_selectedTextOverlay?.font ?? _draftTextFont) == font, onTap: () { KnockHaptics.tap(); setState(() { if (_selectedTextOverlay != null) { _selectedTextOverlay!.font = font; } else { _draftTextFont = font; } }); }))).toList())),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: _textColors.map((color) => _colorDot(color: color, selected: (_selectedTextOverlay?.color ?? _draftTextColor) == color, onTap: () { KnockHaptics.tap(); setState(() { if (_selectedTextOverlay != null) { _selectedTextOverlay!.color = color; } else { _draftTextColor = color; } }); })).toList()),
      ],
    );
  }

  Widget _buildEffectsSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeader(title: 'Cinematic Effects', subtitle: 'Apply premium mood and styling to your video.'),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: CinematicEffect.values.map((effect) {
               final isSelected = _effects.filter == effect;
               return GestureDetector(
                 onTap: () {
                    KnockHaptics.tap();
                    setState(() => _effects = _effects.copyWith(filter: effect));
                 },
                 child: Container(
                   margin: const EdgeInsets.only(right: 12),
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   decoration: BoxDecoration(
                     color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.15))
                   ),
                   child: Text(
                      effect.name.toUpperCase(),
                      style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)
                   )
                 )
               );
            }).toList()
          )
        )
      ],
    );
  }

  Widget _buildCoverSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHeader(title: 'Cover', subtitle: 'Use a frame from the video or upload a custom cover image.'),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ SizedBox(width: 70, height: 70 / _selectedAspect.ratio, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildCoverPreview())), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(_customCoverImage != null ? 'Custom cover selected' : 'Frame at ${_formatDuration(_coverTime)}', style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('Used in feed and grid.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5, height: 1.4)) ])) ]),
        const SizedBox(height: 14),
        Row(children: [ Expanded(child: _secondaryAction(icon: Icons.play_circle_outline_rounded, label: 'Use Current Frame', onTap: () => _selectCoverTime(_playbackPosition))), const SizedBox(width: 10), Expanded(child: _secondaryAction(icon: Icons.add_photo_alternate_outlined, label: 'Upload Cover', onTap: _pickCustomCoverImage)) ]),
        const SizedBox(height: 14),
        SizedBox(height: 74, child: _frameThumbnails.isEmpty ? _buildCoverStripSkeleton() : ListView.separated(scrollDirection: Axis.horizontal, itemCount: _frameThumbnails.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (context, index) { final frame = _frameThumbnails[index]; final isSelected = _customCoverImage == null && (frame.time.inMilliseconds - _coverTime.inMilliseconds).abs() < 400; return GestureDetector(onTap: () => _selectCoverTime(frame.time), child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.12), width: isSelected ? 2 : 1)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(frame.bytes, fit: BoxFit.cover)))); })),
      ],
    );
  }

  Widget _buildFilmstrip() {
    if (_frameThumbnails.isEmpty) return SizedBox(height: 54, child: Row(children: List.generate(8, (index) => Expanded(child: Container(margin: EdgeInsets.only(right: index == 7 ? 0 : 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)))))));
    return SizedBox(height: 54, child: Row(children: _frameThumbnails.map((frame) => Expanded(child: Container(margin: EdgeInsets.only(right: frame == _frameThumbnails.last ? 0 : 2), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(frame.bytes, fit: BoxFit.cover))))).toList()));
  }

  Widget _buildCoverPreview() {
    if (_customCoverImage != null) return Image.file(_customCoverImage!, fit: BoxFit.cover);
    final selected = _frameThumbnails.isEmpty ? null : _frameThumbnails.reduce((current, next) => (current.time.inMilliseconds - _coverTime.inMilliseconds).abs() < (next.time.inMilliseconds - _coverTime.inMilliseconds).abs() ? current : next);
    if (selected == null) return Container(color: Colors.black, child: const Center(child: Icon(Icons.image_outlined, color: Colors.white54)));
    return Image.memory(selected.bytes, fit: BoxFit.cover);
  }

  Widget _buildCoverStripSkeleton() {
    return Row(children: List.generate(5, (index) => Expanded(child: Container(margin: EdgeInsets.only(right: index == 4 ? 0 : 10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12))))));
  }

  Widget _buildTextComposerOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _isAddingText = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.68),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                      child: Column(
                        children: [
                          TextField(controller: _textInputController, autofocus: true, maxLines: 3, textAlign: TextAlign.center, style: TextStyle(color: _draftTextColor, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: _draftTextFont.fontFamily), decoration: InputDecoration(hintText: 'Type something...', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 22), border: InputBorder.none)),
                          const SizedBox(height: 12),
                          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: VideoPostTextFont.values.map((font) => Padding(padding: const EdgeInsets.only(right: 10), child: _fontChip(font: font, selected: _draftTextFont == font, onTap: () => setState(() => _draftTextFont = font)))).toList())),
                          const SizedBox(height: 12),
                          Wrap(spacing: 10, runSpacing: 10, children: _textColors.map((color) => _colorDot(color: color, selected: _draftTextColor == color, onTap: () => setState(() => _draftTextColor = color))).toList()),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [ _previewCircleButton(icon: Icons.close_rounded, onTap: () { setState(() => _isAddingText = false); _textInputController.clear(); }), const SizedBox(width: 16), GestureDetector(onTap: _addTextOverlay, child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)))) ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedTrackCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: _selectedMusic!.coverUrl.isNotEmpty ? Image.network(_selectedMusic!.coverUrl, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: Colors.white.withValues(alpha: 0.06), child: const Icon(Icons.music_note_rounded, color: Colors.white54))) : Container(width: 48, height: 48, color: Colors.white.withValues(alpha: 0.06), child: const Icon(Icons.music_note_rounded, color: Colors.white54))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(_selectedMusic!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text('${_selectedMusic!.artist} • ${_selectedMusic!.duration}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5)), if (_isLoadingMusic || _isCachingMusic) ...[ const SizedBox(height: 8), LinearProgressIndicator(backgroundColor: Colors.white.withValues(alpha: 0.08), color: Colors.white, minHeight: 2) ] ])),
        ],
      ),
    );
  }

  Widget _volumeRow({required String label, required IconData icon, required double value, required bool enabled, required Future<void> Function(double)? onChanged}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: enabled ? Colors.white.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.28)), const SizedBox(width: 10),
        SizedBox(width: 88, child: Text(label, style: TextStyle(color: enabled ? Colors.white.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.28), fontSize: 12, fontWeight: FontWeight.w700))),
        Expanded(child: SliderTheme(data: _sliderTheme(), child: Slider(value: value.clamp(0.0, 1.0), onChanged: enabled && onChanged != null ? (next) => onChanged(next) : null))),
      ],
    );
  }

  Widget _actionCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Row(children: [ Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11.5)) ])), Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withValues(alpha: 0.4)) ]),
    );
  }

  Widget _toolButton({required IconData icon, required String label, required _VideoEditorTool tool}) {
    final isActive = _activeTool == tool;
    return GestureDetector(
      onTap: () => _setTool(tool),
      child: AnimatedContainer(duration: const Duration(milliseconds: 220), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: Border.all(color: isActive ? Colors.white.withValues(alpha: 0.3) : Colors.transparent)), child: Column(mainAxisSize: MainAxisSize.min, children: [ Icon(icon, size: 22, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.45), letterSpacing: 0.3)) ])),
    );
  }

  Widget _secondaryAction({required IconData icon, required String label, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), decoration: BoxDecoration(color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.12))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(icon, color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35), size: 18), const SizedBox(width: 8), Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35), fontSize: 12, fontWeight: FontWeight.w700))) ])));
  }

  Widget _sheetHeader({required String title, required String subtitle}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5, height: 1.4)) ]);
  }

  Widget _previewCircleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(onTap: onTap, child: ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.15))), child: Center(child: Icon(icon, color: Colors.white, size: 18))))));
  }

  Widget _fontChip({required VideoPostTextFont font, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12))), child: Text(font.label, style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: font.fontFamily))));
  }

  Widget _colorDot({required Color color, required bool selected, required VoidCallback onTap}) {
    final borderColor = color == Colors.white ? Colors.black12 : Colors.white24;
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: selected ? Colors.white : borderColor, width: selected ? 3.0 : 1.3))));
  }

  SliderThemeData _sliderTheme() {
    return SliderTheme.of(context).copyWith(
      trackHeight: 3.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
      thumbColor: Colors.white,
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      overlayColor: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildExportOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_exportProgress != null)
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: _exportProgress,
                  color: Colors.white,
                  strokeWidth: 4.0,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
              )
            else
              const SizedBox(width: 32, height: 32, child: KnockPostLoadingIndicator()),
            
            const SizedBox(height: 18),
            Text(
              _exportProgress != null && _exportProgress! > 0
                  ? 'Processing... ${(_exportProgress! * 100).toInt()}%' 
                  : _exportStatusText, 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 14, 
                fontWeight: FontWeight.w700, 
                letterSpacing: 0.5
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameThumbnail {
  final Duration time;
  final Uint8List bytes;
  const _FrameThumbnail({required this.time, required this.bytes});
}

class _EditableVideoText {
  String text;
  double x;
  double y;
  double scale = 1.0;
  double rotation = 0.0;
  Color color;
  VideoPostTextFont font;
  Duration? startTime;
  Duration? endTime;

  double gestureBaseScale = 1.0;
  double gestureBaseRotation = 0.0;
  Offset gestureStartFocal = Offset.zero;
  Offset gestureStartPosition = Offset.zero;

  _EditableVideoText({
    required this.text, required this.x, required this.y,
    this.color = Colors.white, this.font = VideoPostTextFont.classic,
    this.startTime, this.endTime,
  });

  VideoPostTextOverlay toProcessingOverlay() {
    return VideoPostTextOverlay(text: text, x: x, y: y, scale: scale, rotation: rotation, color: color, font: font, startTime: startTime, endTime: endTime);
  }
}

class _EditableSticker {
  String emoji;
  double x;
  double y;
  double scale = 1.0;
  double rotation = 0.0;
  Duration? startTime;
  Duration? endTime;

  double gestureBaseScale = 1.0;
  double gestureBaseRotation = 0.0;
  Offset gestureStartFocal = Offset.zero;
  Offset gestureStartPosition = Offset.zero;

  _EditableSticker({
    required this.emoji, required this.x, required this.y,
    this.startTime, this.endTime,
  });

  VideoPostStickerOverlay toProcessingOverlay() {
    return VideoPostStickerOverlay(emoji: emoji, x: x, y: y, scale: scale, rotation: rotation, startTime: startTime, endTime: endTime);
  }
}
