import 'dart:async';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../utils/audio_lifecycle_manager.dart';
import '../../utils/haptic_helper.dart';
import 'music_picker_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MusicStickerConfig — Lightweight sticker placement model
// ─────────────────────────────────────────────────────────────────────────────

class MusicStickerConfig {
  final bool showSticker;
  final double dx;
  final double dy;
  final double scale;

  const MusicStickerConfig({
    this.showSticker = true,
    this.dx = 0.0,
    this.dy = 0.0,
    this.scale = 1.0,
  });

  factory MusicStickerConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MusicStickerConfig();
    return MusicStickerConfig(
      showSticker: map['showSticker'] as bool? ?? true,
      dx: (map['dx'] as num?)?.toDouble() ?? 0.0,
      dy: (map['dy'] as num?)?.toDouble() ?? 0.0,
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'showSticker': showSticker,
        'dx': dx,
        'dy': dy,
        'scale': scale,
      };

  MusicStickerConfig copyWith({bool? showSticker, double? dx, double? dy, double? scale}) {
    return MusicStickerConfig(
      showSticker: showSticker ?? this.showSticker,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      scale: scale ?? this.scale,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MusicOverlayScreen — Premium cinematic music editor
// ─────────────────────────────────────────────────────────────────────────────

class MusicOverlayScreen extends StatefulWidget {
  final MusicTrack track;
  final bool isVideo;

  const MusicOverlayScreen({
    super.key,
    required this.track,
    this.isVideo = false,
  });

  @override
  State<MusicOverlayScreen> createState() => _MusicOverlayScreenState();
}

class _MusicOverlayScreenState extends State<MusicOverlayScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  late MusicStickerConfig _config;
  late AnimationController _fadeCtrl;

  double _totalMs = 30000;
  double _positionMs = 0;
  double _startMs = 0;
  double _endMs = 15000;

  double _originalVolume = 1.0;
  double _musicVolume = 1.0;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isScrubbing = false;
  bool _isDraggingTrim = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    AudioLifecycleManager.instance.register(_player);
    _config = const MusicStickerConfig();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 0,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.setLoopMode(LoopMode.off);
      await _player.setUrl(widget.track.previewUrl);

      Duration? duration = _player.duration;
      for (int attempt = 0; attempt < 25 && duration == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        duration = _player.duration;
      }

      final totalMs = (duration?.inMilliseconds ?? 30000).toDouble();

      if (!mounted) return;

      setState(() {
        _totalMs = totalMs;
        _startMs = 0;
        _endMs = math.min<double>(15000, totalMs);
        _positionMs = 0;
        _isLoading = false;
      });

      _fadeCtrl.forward();

      _positionSub = _player.positionStream.listen((position) {
        if (!mounted) return;
        final ms = position.inMilliseconds.toDouble();
        if (!_isScrubbing) {
          setState(() => _positionMs = ms);
        }
        if (ms >= _endMs && _isPlaying) {
          _player.pause();
          _player.seek(Duration(milliseconds: _startMs.round()));
        }
      });

      _playerStateSub = _player.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlaying = state.playing);
      });

      await _player.seek(Duration.zero);
      await _player.play();
    } catch (error) {
      debugPrint('Music overlay init error: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _fadeCtrl.dispose();
    AudioLifecycleManager.instance.unregister(_player);
    _player.stop().whenComplete(() => _player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    KnockHaptics.tap();
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    if (_positionMs >= _endMs || _positionMs < _startMs) {
      await _player.seek(Duration(milliseconds: _startMs.round()));
    }
    await _player.play();
  }

  Future<void> _seekTo(double ms) async {
    final clamped = ms.clamp(_startMs, _endMs).toDouble();
    setState(() {
      _positionMs = clamped;
      _isScrubbing = true;
    });
    await _player.seek(Duration(milliseconds: clamped.round()));
    if (mounted) setState(() => _isScrubbing = false);
  }

  void _onTrimStartDrag(DragUpdateDetails details, double width) {
    final deltaMs = (details.delta.dx / width) * _totalMs;
    final nextStart = (_startMs + deltaMs).clamp(0.0, _endMs - 1000).toDouble();
    final safeStart = _endMs - nextStart > 15000 ? _endMs - 15000 : nextStart;
    setState(() {
      _startMs = safeStart;
      if (_positionMs < _startMs) _positionMs = _startMs;
    });
    _seekTo(_positionMs);
  }

  void _onTrimEndDrag(DragUpdateDetails details, double width) {
    final deltaMs = (details.delta.dx / width) * _totalMs;
    final nextEnd = (_endMs + deltaMs).clamp(_startMs + 1000, _totalMs).toDouble();
    final safeEnd = nextEnd - _startMs > 15000 ? _startMs + 15000 : nextEnd;
    setState(() {
      _endMs = safeEnd;
      if (_positionMs > _endMs) _positionMs = _endMs;
    });
    _seekTo(_positionMs);
  }

  void _finishSelection() {
    KnockHaptics.tap();
    Navigator.pop(context, <String, dynamic>{
      'track': widget.track,
      'trimStartSeconds': (_startMs / 1000).floor(),
      'stickerConfig': _config.toMap(),
      'originalVolume': _originalVolume,
      'musicVolume': _musicVolume,
    });
  }

  String _fmtDur(double milliseconds) {
    final d = Duration(milliseconds: milliseconds.round());
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred glass background ──
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0D0D0D).withValues(alpha: 0.92),
                        const Color(0xFF111118).withValues(alpha: 0.96),
                        Colors.black.withValues(alpha: 0.98),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Subtle ambient glow ──
          Positioned(
            top: -80,
            left: -40,
            width: 260,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: KnockpostLoadingIndicator(),
                    ),
                  )
                else
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeCtrl,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 8,
                          bottom: math.max(bottomPad, 20) + 8,
                        ),
                        child: Column(
                          children: [
                            // ── Preview section ──
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: _config.showSticker
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: 20),
                                      child: MusicStickerWidget(
                                        title: widget.track.title,
                                        artist: widget.track.artist,
                                        coverUrl: widget.track.coverUrl,
                                        configData: _config.toMap(),
                                        isPlaying: _isPlaying,
                                      ),
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),

                            // ── Music card ──
                            _buildMusicCard(),
                            const SizedBox(height: 20),

                            // ── Trimmer (hero section) ──
                            _buildTrimmerSection(),
                            const SizedBox(height: 24),

                            // ── Music Sticker Toggle ──
                            _buildStickerToggle(),
                            const SizedBox(height: 20),

                            // ── Volume section ──
                            _buildVolumeSection(),
                          ],
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

  // ─── TOP BAR ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: () {
              KnockHaptics.tap();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'MUSIC EDITOR',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 2.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Done button
          GestureDetector(
            onTap: _finishSelection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MUSIC CARD ────────────────────────────────────────────────────────────

  Widget _buildMusicCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: widget.track.coverUrl.isNotEmpty
                ? ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.saturation,
                    ),
                    child: Image.network(
                      widget.track.coverUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackArt(52),
                    ),
                  )
                : _fallbackArt(52),
          ),
          const SizedBox(width: 14),

          // Song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.track.artist}  ·  ${widget.track.duration}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Mini equalizer
          if (_isPlaying) _buildMiniEqualizer(),
          if (_isPlaying) const SizedBox(width: 10),

          // Play/Pause
          GestureDetector(
            onTap: _togglePlayback,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isPlaying
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _isPlaying ? 0.2 : 0.1),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(_isPlaying),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEqualizer() {
    return SizedBox(
      width: 16,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          return _AnimatedEqualizerBar(
            delay: Duration(milliseconds: i * 120),
            isPlaying: _isPlaying,
          );
        }),
      ),
    );
  }

  // ─── TRIMMER SECTION ───────────────────────────────────────────────────────

  Widget _buildTrimmerSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDur(_startMs),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fmtDur(_endMs - _startMs),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                _fmtDur(_endMs),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Waveform + trim handles
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final startX = (_startMs / _totalMs) * width;
              final endX = (_endMs / _totalMs) * width;
              final playheadX = ((_positionMs.clamp(_startMs, _endMs)) / _totalMs) * width;

              return GestureDetector(
                onTapDown: (details) {
                  final targetMs = (details.localPosition.dx / width) * _totalMs;
                  _seekTo(targetMs);
                },
                child: SizedBox(
                  height: 64,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Waveform background
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomPaint(painter: _WaveformPainter()),
                          ),
                        ),
                      ),

                      // Dimmed region: before start
                      if (startX > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: startX,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                bottomLeft: const Radius.circular(14),
                                topRight: startX >= width ? const Radius.circular(14) : Radius.zero,
                                bottomRight: startX >= width ? const Radius.circular(14) : Radius.zero,
                              ),
                            ),
                          ),
                        ),

                      // Dimmed region: after end
                      if (endX < width)
                        Positioned(
                          left: endX,
                          top: 0,
                          bottom: 0,
                          width: width - endX,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.only(
                                topRight: const Radius.circular(14),
                                bottomRight: const Radius.circular(14),
                                topLeft: endX <= 0 ? const Radius.circular(14) : Radius.zero,
                                bottomLeft: endX <= 0 ? const Radius.circular(14) : Radius.zero,
                              ),
                            ),
                          ),
                        ),

                      // Active selection border
                      Positioned(
                        left: startX,
                        top: 0,
                        bottom: 0,
                        width: (endX - startX).clamp(0, width),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isDraggingTrim
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isDraggingTrim
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),

                      // Playhead
                      Positioned(
                        left: (playheadX - 1).clamp(0, width - 2),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2.5,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Start handle
                      Positioned(
                        left: startX - 14,
                        top: -2,
                        bottom: -2,
                        width: 28,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: (_) => setState(() => _isDraggingTrim = true),
                          onHorizontalDragUpdate: (d) => _onTrimStartDrag(d, width),
                          onHorizontalDragEnd: (_) => setState(() => _isDraggingTrim = false),
                          child: Center(child: _trimHandle()),
                        ),
                      ),

                      // End handle
                      Positioned(
                        left: endX - 14,
                        top: -2,
                        bottom: -2,
                        width: 28,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: (_) => setState(() => _isDraggingTrim = true),
                          onHorizontalDragUpdate: (d) => _onTrimEndDrag(d, width),
                          onHorizontalDragEnd: (_) => setState(() => _isDraggingTrim = false),
                          child: Center(child: _trimHandle()),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // Seek slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.04),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: _positionMs.clamp(_startMs, _endMs),
              min: _startMs,
              max: _endMs <= _startMs ? _startMs + 1 : _endMs,
              onChanged: (v) => _seekTo(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trimHandle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _isDraggingTrim ? 8 : 5,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: _isDraggingTrim ? 8 : 4,
          ),
          if (_isDraggingTrim)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
    );
  }

  // ─── STICKER TOGGLE ────────────────────────────────────────────────────────

  Widget _buildStickerToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // Main toggle row
          Row(
            children: [
              // Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _config.showSticker
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.album_rounded,
                  color: _config.showSticker ? Colors.white : Colors.white38,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),

              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Music Sticker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _config.showSticker ? 'Visible on post' : 'Hidden',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // iOS-style toggle
              GestureDetector(
                onTap: () {
                  KnockHaptics.tap();
                  setState(() => _config = _config.copyWith(showSticker: !_config.showSticker));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 50,
                  height: 30,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: _config.showSticker
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: _config.showSticker ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _config.showSticker ? Colors.black : Colors.white54,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── VOLUME SECTION ────────────────────────────────────────────────────────

  Widget _buildVolumeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VOLUME',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (widget.isVideo) ...[
            _buildVolumeRow(
              icon: Icons.videocam_rounded,
              label: 'Original',
              value: _originalVolume,
              onChanged: (v) => setState(() => _originalVolume = v),
            ),
            const SizedBox(height: 12),
          ],
          _buildVolumeRow(
            icon: Icons.music_note_rounded,
            label: 'Music',
            value: _musicVolume,
            onChanged: (v) {
              setState(() => _musicVolume = v);
              _player.setVolume(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeRow({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.04),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  Widget _fallbackArt([double size = 52]) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white30, size: 22),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedEqualizerBar — Smooth staggered waveform bar for the music card
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedEqualizerBar extends StatefulWidget {
  final Duration delay;
  final bool isPlaying;

  const _AnimatedEqualizerBar({required this.delay, required this.isPlaying});

  @override
  State<_AnimatedEqualizerBar> createState() => _AnimatedEqualizerBarState();
}

class _AnimatedEqualizerBarState extends State<_AnimatedEqualizerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    if (widget.isPlaying) {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.repeat(reverse: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedEqualizerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final h = 4.0 + (_ctrl.value * 14);
        return Container(
          width: 3,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WaveformPainter — Static waveform bars for the trimmer
// ─────────────────────────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  static const List<double> _heights = [
    0.28, 0.48, 0.68, 0.38, 0.92, 0.56, 0.30, 0.74, 0.44, 0.96,
    0.34, 0.62, 0.84, 0.26, 0.68, 0.40, 0.78, 0.32, 0.54, 0.72,
    0.42, 0.60, 0.88, 0.36, 0.76, 0.50, 0.66, 0.44, 0.82, 0.38,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    const barW = 3.0;
    const gap = 2.0;
    final count = (size.width / (barW + gap)).floor();
    for (int i = 0; i < count; i++) {
      final x = i * (barW + gap);
      final ratio = _heights[i % _heights.length];
      final h = size.height * ratio * 0.75;
      final y = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW, h), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// MusicStickerWidget — Premium glassmorphism sticker for posts
// ─────────────────────────────────────────────────────────────────────────────

class MusicStickerWidget extends StatefulWidget {
  final String title;
  final String artist;
  final String coverUrl;
  final Map<String, dynamic>? configData;
  final bool isPlaying;
  final bool isEditable;
  final ValueChanged<MusicStickerConfig>? onConfigChanged;

  const MusicStickerWidget({
    super.key,
    required this.title,
    required this.artist,
    required this.coverUrl,
    this.configData,
    this.isPlaying = false,
    this.isEditable = false,
    this.onConfigChanged,
  });

  @override
  State<MusicStickerWidget> createState() => _MusicStickerWidgetState();
}

class _MusicStickerWidgetState extends State<MusicStickerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isPlaying) _animCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MusicStickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animCtrl.repeat(reverse: true);
      } else {
        _animCtrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = MusicStickerConfig.fromMap(widget.configData);
    if (!config.showSticker) return const SizedBox.shrink();

    const artSize = 40.0;
    const borderRadius = 16.0;
    const hPad = 14.0;
    const vPad = 10.0;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.coverUrl.isNotEmpty
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            ),
                            child: Image.network(
                              widget.coverUrl,
                              width: artSize,
                              height: artSize,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallbackCover(artSize),
                            ),
                          )
                        : _fallbackCover(artSize),
                  ),
                  const SizedBox(width: 12),

                  // Text + mini waveform
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (widget.isPlaying) ...[
                              const SizedBox(width: 6),
                              _buildMiniWaveform(false),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (widget.isEditable && widget.onConfigChanged != null) {
        content = GestureDetector(
          onScaleStart: (details) {
            _baseScale = config.scale;
          },
          onScaleUpdate: (details) {
            widget.onConfigChanged!(config.copyWith(
              dx: config.dx + details.focalPointDelta.dx,
              dy: config.dy + details.focalPointDelta.dy,
              scale: (_baseScale * details.scale).clamp(0.4, 4.0),
            ));
          },
          child: content,
        );
      }

      return Align(
        alignment: Alignment.center,
        child: Transform.translate(
          offset: Offset(config.dx, config.dy),
          child: Transform.scale(
            scale: config.scale,
            child: content,
          ),
        ),
      );
  }

  Widget _buildMiniWaveform(bool isSmall) {
    final barH = isSmall ? 5.0 : 7.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animCtrl,
          builder: (_, __) {
            final offset = index * 0.3;
            final val = math.sin((_animCtrl.value * math.pi * 2) + offset).abs();
            return Container(
              width: 2,
              height: 3 + (val * barH),
              margin: const EdgeInsets.only(right: 1.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _fallbackCover(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white38,
        size: size * 0.5,
      ),
    );
  }
}
