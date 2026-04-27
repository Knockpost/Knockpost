import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';

import '../../utils/audio_lifecycle_manager.dart';
import '../../utils/haptic_helper.dart';
import 'music_picker_screen.dart';

class LyricWordSegment {
  final String text;
  final Duration startTime;
  final Duration endTime;

  const LyricWordSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

class LrcLine {
  final Duration time;
  final Duration endTime;
  final String text;
  final List<LyricWordSegment> words;

  const LrcLine({
    required this.time,
    required this.endTime,
    required this.text,
    required this.words,
  });
}

class LyricsOverlayConfig {
  final int styleIndex;
  final int themeIndex;
  final int fontIndex;
  final int backgroundIndex;
  final int anchorIndex;

  const LyricsOverlayConfig({
    this.styleIndex = 1,
    this.themeIndex = 0,
    this.fontIndex = 0,
    this.backgroundIndex = 1,
    this.anchorIndex = 1,
  });

  factory LyricsOverlayConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const LyricsOverlayConfig();
    }
    return LyricsOverlayConfig(
      styleIndex: (map['styleIndex'] as num?)?.toInt() ?? 1,
      themeIndex: (map['themeIndex'] as num?)?.toInt() ?? 0,
      fontIndex: (map['fontIndex'] as num?)?.toInt() ?? 0,
      backgroundIndex: (map['backgroundIndex'] as num?)?.toInt() ?? 1,
      anchorIndex: (map['anchorIndex'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'styleIndex': styleIndex,
      'themeIndex': themeIndex,
      'fontIndex': fontIndex,
      'backgroundIndex': backgroundIndex,
      'anchorIndex': anchorIndex,
    };
  }

  LyricsOverlayConfig copyWith({
    int? styleIndex,
    int? themeIndex,
    int? fontIndex,
    int? backgroundIndex,
    int? anchorIndex,
  }) {
    return LyricsOverlayConfig(
      styleIndex: styleIndex ?? this.styleIndex,
      themeIndex: themeIndex ?? this.themeIndex,
      fontIndex: fontIndex ?? this.fontIndex,
      backgroundIndex: backgroundIndex ?? this.backgroundIndex,
      anchorIndex: anchorIndex ?? this.anchorIndex,
    );
  }
}

class _LyricsThemePalette {
  final String label;
  final Color inactiveColor;
  final Color activeColor;
  final Color accentColor;
  final Color glowColor;
  final Color shadowColor;

  const _LyricsThemePalette({
    required this.label,
    required this.inactiveColor,
    required this.activeColor,
    required this.accentColor,
    required this.glowColor,
    required this.shadowColor,
  });
}

class _LyricsFontProfile {
  final String label;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final double letterSpacing;
  final String? fontFamily;

  const _LyricsFontProfile({
    required this.label,
    required this.fontWeight,
    this.fontStyle = FontStyle.normal,
    this.letterSpacing = 0,
    this.fontFamily,
  });
}

class _RawLrcLine {
  final Duration start;
  final String rawText;

  const _RawLrcLine({required this.start, required this.rawText});
}

const List<String> _lyricsStyleLabels = <String>[
  'Hidden',
  'Karaoke',
  'Fade',
  'Type',
];

const List<String> _backgroundLabels = <String>[
  'None',
  'Soft',
  'Glass',
];

const List<String> _anchorLabels = <String>[
  'Top',
  'Center',
  'Bottom',
];

const List<_LyricsThemePalette> _lyricsThemes = <_LyricsThemePalette>[
  _LyricsThemePalette(
    label: 'White',
    inactiveColor: Color(0xB3FFFFFF),
    activeColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFF2F2F2),
    glowColor: Color(0xCCFFFFFF),
    shadowColor: Color(0xCC000000),
  ),
  _LyricsThemePalette(
    label: 'Sunset',
    inactiveColor: Color(0xFFFFE1D6),
    activeColor: Color(0xFFFFB183),
    accentColor: Color(0xFFFF7A5C),
    glowColor: Color(0x99FF8B63),
    shadowColor: Color(0xB340150F),
  ),
  _LyricsThemePalette(
    label: 'Neon',
    inactiveColor: Color(0xAAE0FFFF),
    activeColor: Color(0xFF7CF7FF),
    accentColor: Color(0xFF5AD6FF),
    glowColor: Color(0xCC36DFFF),
    shadowColor: Color(0xCC001620),
  ),
];

const List<_LyricsFontProfile> _lyricsFonts = <_LyricsFontProfile>[
  _LyricsFontProfile(
    label: 'Bold',
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  ),
  _LyricsFontProfile(
    label: 'Aesthetic',
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    fontFamily: 'serif',
  ),
  _LyricsFontProfile(
    label: 'Handwritten',
    fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic,
    letterSpacing: 0.2,
  ),
];

final RegExp _lineTimestampRegex = RegExp(r'\[(\d{2}):(\d{2})[.:](\d{2,3})\]');
final RegExp _wordTimestampRegex = RegExp(r'<(\d{2}):(\d{2})[.:](\d{2,3})>');

List<LrcLine> parseLrc(String lrc) {
  final List<_RawLrcLine> rawLines = <_RawLrcLine>[];

  for (final sourceLine in lrc.split(RegExp(r'\r?\n'))) {
    final matches = _lineTimestampRegex.allMatches(sourceLine).toList();
    if (matches.isEmpty) {
      continue;
    }
    final rawText = sourceLine.replaceAll(_lineTimestampRegex, '').trim();
    if (rawText.isEmpty) {
      continue;
    }

    for (final match in matches) {
      rawLines.add(
        _RawLrcLine(
          start: _parseTimestampParts(
            match.group(1)!,
            match.group(2)!,
            match.group(3)!,
          ),
          rawText: rawText,
        ),
      );
    }
  }

  rawLines.sort((a, b) => a.start.compareTo(b.start));
  if (rawLines.isEmpty) {
    return const <LrcLine>[];
  }

  final List<LrcLine> lines = <LrcLine>[];
  for (int index = 0; index < rawLines.length; index++) {
    final raw = rawLines[index];
    final end = index + 1 < rawLines.length
        ? rawLines[index + 1].start
        : raw.start + const Duration(seconds: 3);
    final safeEnd = end > raw.start
        ? end
        : raw.start + const Duration(seconds: 2);
    final normalizedText = _stripWordTags(raw.rawText);
    final words = _extractWordSegments(
      raw.rawText,
      normalizedText,
      raw.start,
      safeEnd,
    );

    lines.add(
      LrcLine(
        time: raw.start,
        endTime: safeEnd,
        text: normalizedText,
        words: words,
      ),
    );
  }

  return lines;
}

LyricsOverlayConfig defaultLyricsOverlayConfig([int styleIndex = 1]) {
  return LyricsOverlayConfig(styleIndex: styleIndex);
}

Offset defaultMusicLyricsOverlayOffset({
  required double frameWidth,
  required double frameHeight,
  Map<String, dynamic>? lyricsConfigData,
}) {
  final config = LyricsOverlayConfig.fromMap(lyricsConfigData);
  final double top = switch (config.anchorIndex) {
    0 => frameHeight * 0.14,
    2 => frameHeight * 0.68,
    _ => frameHeight * 0.42,
  };

  return Offset(frameWidth * 0.1, top);
}

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

class _MusicOverlayScreenState extends State<MusicOverlayScreen> {
  final AudioPlayer _player = AudioPlayer();

  late LyricsOverlayConfig _config;
  List<LrcLine> _lyrics = const <LrcLine>[];

  double _totalMs = 30000;
  double _positionMs = 0;
  double _startMs = 0;
  double _endMs = 15000;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isScrubbing = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    AudioLifecycleManager.instance.register(_player);
    _config = defaultLyricsOverlayConfig();
    _initialize();
  }

  Future<void> _initialize() async {
    final parsedLyrics = widget.track.syncedLyrics?.trim().isNotEmpty == true
        ? parseLrc(widget.track.syncedLyrics!)
        : _fallbackLyricsForTrack(widget.track);

    try {
      await _player.setLoopMode(LoopMode.off);
      await _player.setUrl(widget.track.previewUrl);

      Duration? duration = _player.duration;
      for (int attempt = 0; attempt < 25 && duration == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        duration = _player.duration;
      }

      final totalMs = (duration?.inMilliseconds ?? 30000).toDouble();

      if (!mounted) {
        return;
      }

      setState(() {
        _lyrics = parsedLyrics;
        _totalMs = totalMs;
        _startMs = 0;
        _endMs = math.min<double>(15000, totalMs);
        _positionMs = 0;
        _isLoading = false;
      });

      _positionSub = _player.positionStream.listen((position) {
        if (!mounted) {
          return;
        }
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
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });

      await _player.seek(Duration.zero);
      await _player.play();
    } catch (error) {
      debugPrint('Music overlay init error: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _lyrics = parsedLyrics;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    AudioLifecycleManager.instance.unregister(_player);
    _player.stop().whenComplete(() => _player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
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
    if (mounted) {
      setState(() => _isScrubbing = false);
    }
  }

  void _onTrimStartDrag(DragUpdateDetails details, double width) {
    final deltaMs = (details.delta.dx / width) * _totalMs;
    final nextStart = (_startMs + deltaMs).clamp(0.0, _endMs - 1000).toDouble();
    final safeStart = _endMs - nextStart > 15000 ? _endMs - 15000 : nextStart;
    setState(() {
      _startMs = safeStart;
      if (_positionMs < _startMs) {
        _positionMs = _startMs;
      }
    });
    _seekTo(_positionMs);
  }

  void _onTrimEndDrag(DragUpdateDetails details, double width) {
    final deltaMs = (details.delta.dx / width) * _totalMs;
    final nextEnd = (_endMs + deltaMs).clamp(_startMs + 1000, _totalMs).toDouble();
    final safeEnd = nextEnd - _startMs > 15000 ? _startMs + 15000 : nextEnd;
    setState(() {
      _endMs = safeEnd;
      if (_positionMs > _endMs) {
        _positionMs = _endMs;
      }
    });
    _seekTo(_positionMs);
  }

  void _updateConfig(LyricsOverlayConfig nextConfig) {
    KnockHaptics.tap();
    setState(() => _config = nextConfig);
  }

  void _finishSelection() {
    KnockHaptics.tap();
    Navigator.pop(
      context,
      <String, dynamic>{
        'track': widget.track,
        'trimStartSeconds': (_startMs / 1000).floor(),
        'styleIndex': _config.styleIndex,
        'lyricsConfig': _config.toMap(),
      },
    );
  }

  String _formatDuration(double milliseconds) {
    final value = Duration(milliseconds: milliseconds.round());
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const previewAspectRatio = 4 / 5; // Always use a wider card ratio for safe text rendering
    final hasSyncedLyrics =
        widget.track.syncedLyrics?.trim().isNotEmpty == true &&
        _lyrics.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                _buildHeader(),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: <Widget>[
                                Expanded(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: previewAspectRatio,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(28),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: <Color>[
                                              Color(0xFF262626),
                                              Color(0xFF0D0D0D),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.08),
                                          ),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.32),
                                              blurRadius: 28,
                                              spreadRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: <Widget>[
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(28),
                                                gradient: RadialGradient(
                                                  center: Alignment.topCenter,
                                                  radius: 1.2,
                                                  colors: <Color>[
                                                    Colors.white.withValues(alpha: 0.08),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                children: <Widget>[
                                                  Row(
                                                    children: <Widget>[
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(14),
                                                        child: widget.track.coverUrl.isNotEmpty
                                                            ? Image.network(
                                                                widget.track.coverUrl,
                                                                width: 54,
                                                                height: 54,
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (_, __, ___) => _fallbackArt(),
                                                              )
                                                            : _fallbackArt(),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: <Widget>[
                                                            Text(
                                                              widget.track.title,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 3),
                                                            Text(
                                                              widget.track.artist,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                color: Colors.white.withValues(alpha: 0.58),
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const Spacer(),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: MusicStyleOverlayWidget(
                                                      styleIndex: _config.styleIndex,
                                                      title: widget.track.title,
                                                      artist: widget.track.artist,
                                                      coverUrl: widget.track.coverUrl,
                                                      lyricsLrc: widget.track.syncedLyrics,
                                                      lyricsConfigData: _config.toMap(),
                                                      timelinePositionMs: _positionMs.round(),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (!hasSyncedLyrics)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.07),
                                                        borderRadius: BorderRadius.circular(14),
                                                      ),
                                                      child: Text(
                                                        'No synced lyrics found. KnockPost will animate the track title and artist as a fallback.',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          color: Colors.white.withValues(alpha: 0.7),
                                                          fontSize: 11,
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Expanded(
                                  child: _buildControlSection(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              KnockHaptics.tap();
              Navigator.pop(context);
            },
            child: _headerCircleButton(Icons.close_rounded),
          ),
          const Text(
            'LYRICS STUDIO',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          GestureDetector(
            onTap: _finishSelection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: <Widget>[
            _buildTransportRow(),
          const SizedBox(height: 14),
          _buildWaveformTrimEditor(),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.08),
            ),
            child: Slider(
              value: _positionMs.clamp(_startMs, _endMs),
              min: _startMs,
              max: _endMs <= _startMs ? _startMs + 1 : _endMs,
              onChanged: (value) => _seekTo(value),
            ),
          ),
          const SizedBox(height: 10),
          _sectionLabel('Animation Style'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(_lyricsStyleLabels.length, (index) {
              return _selectorChip(
                label: _lyricsStyleLabels[index],
                selected: _config.styleIndex == index,
                onTap: () => _updateConfig(_config.copyWith(styleIndex: index)),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildInlineSelector(
                  label: 'Font',
                  values: _lyricsFonts.map((profile) => profile.label).toList(),
                  selectedIndex: _config.fontIndex,
                  onChanged: (index) => _updateConfig(_config.copyWith(fontIndex: index)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInlineSelector(
                  label: 'Theme',
                  values: _lyricsThemes.map((theme) => theme.label).toList(),
                  selectedIndex: _config.themeIndex,
                  onChanged: (index) => _updateConfig(_config.copyWith(themeIndex: index)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildInlineSelector(
                  label: 'Background',
                  values: _backgroundLabels,
                  selectedIndex: _config.backgroundIndex,
                  onChanged: (index) =>
                      _updateConfig(_config.copyWith(backgroundIndex: index)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInlineSelector(
                  label: 'Position',
                  values: _anchorLabels,
                  selectedIndex: _config.anchorIndex,
                  onChanged: (index) =>
                      _updateConfig(_config.copyWith(anchorIndex: index)),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTransportRow() {
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: widget.track.coverUrl.isNotEmpty
              ? Image.network(
                  widget.track.coverUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackArt(46),
                )
              : _fallbackArt(46),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${widget.track.artist}  •  ${widget.track.duration}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            KnockHaptics.tap();
            _togglePlayback();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformTrimEditor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final startX = (_startMs / _totalMs) * width;
        final endX = (_endMs / _totalMs) * width;
        final playheadX = (_positionMs / _totalMs) * width;

        return Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _formatDuration(_startMs),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'clip ${_formatDuration(_endMs - _startMs)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDuration(_endMs),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTapDown: (details) {
                final targetMs = (details.localPosition.dx / width) * _totalMs;
                _seekTo(targetMs);
              },
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(painter: _StaticWaveformPainter()),
                    ),
                    if (startX > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: startX,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.42),
                        ),
                      ),
                    if (endX < width)
                      Positioned(
                        left: endX,
                        top: 0,
                        bottom: 0,
                        width: width - endX,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.42),
                        ),
                      ),
                    Positioned(
                      left: startX,
                      top: 0,
                      bottom: 0,
                      width: endX - startX,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    Positioned(
                      left: playheadX - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: _lyricsThemes[_config.themeIndex].activeColor,
                      ),
                    ),
                    Positioned(
                      left: startX - 12,
                      top: -4,
                      bottom: -4,
                      width: 24,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) =>
                            _onTrimStartDrag(details, width),
                        child: Center(child: _trimHandle()),
                      ),
                    ),
                    Positioned(
                      left: endX - 12,
                      top: -4,
                      bottom: -4,
                      width: 24,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) =>
                            _onTrimEndDrag(details, width),
                        child: Center(child: _trimHandle()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineSelector({
    required String label,
    required List<String> values,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(values.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == values.length - 1 ? 0 : 8,
                  ),
                  child: _selectorChip(
                    label: values[index],
                    selected: selectedIndex == index,
                    onTap: () => onChanged(index),
                    compact: true,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: compact ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _headerCircleButton(IconData icon) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.35),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _fallbackArt([double size = 54]) {
    return Container(
      width: size,
      height: size,
      color: Colors.white.withValues(alpha: 0.06),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white54,
      ),
    );
  }

  Widget _trimHandle() {
    return Container(
      width: 6,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _StaticWaveformPainter extends CustomPainter {
  static const List<double> _barHeights = <double>[
    0.24,
    0.42,
    0.62,
    0.34,
    0.88,
    0.52,
    0.27,
    0.70,
    0.41,
    0.92,
    0.31,
    0.58,
    0.80,
    0.22,
    0.64,
    0.37,
    0.74,
    0.28,
    0.49,
    0.67,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    const barWidth = 3.0;
    const gap = 2.0;
    final count = (size.width / (barWidth + gap)).floor();
    for (int index = 0; index < count; index++) {
      final x = index * (barWidth + gap);
      final ratio = _barHeights[index % _barHeights.length];
      final height = size.height * ratio * 0.82;
      final y = (size.height - height) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MusicStyleOverlayWidget extends StatefulWidget {
  final int styleIndex;
  final String title;
  final String artist;
  final String coverUrl;
  final String? lyricsLrc;
  final Map<String, dynamic>? lyricsConfigData;
  final int timelinePositionMs;

  const MusicStyleOverlayWidget({
    super.key,
    required this.styleIndex,
    required this.title,
    required this.artist,
    required this.coverUrl,
    this.lyricsLrc,
    this.lyricsConfigData,
    this.timelinePositionMs = 0,
  });

  static final Map<String, List<LrcLine>> _lyricsCache = <String, List<LrcLine>>{};

  @override
  State<MusicStyleOverlayWidget> createState() => _MusicStyleOverlayWidgetState();
}

class _MusicStyleOverlayWidgetState extends State<MusicStyleOverlayWidget> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _smoothedMs = 0;
  int _lastTargetMs = 0;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _smoothedMs = widget.timelinePositionMs.toDouble();
    _lastTargetMs = widget.timelinePositionMs;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final now = DateTime.now();
    final timeSinceUpdate = now.difference(_lastUpdateTime).inMilliseconds;

    setState(() {
      if (timeSinceUpdate < 1000) {
        // Extrapolate
        double extrapolatedMs = _lastTargetMs + timeSinceUpdate.toDouble();
        if ((_smoothedMs - extrapolatedMs).abs() > 1000) {
          _smoothedMs = extrapolatedMs;
        } else {
          _smoothedMs += (extrapolatedMs - _smoothedMs) * 0.3;
        }
      } else {
        // Paused
        if ((_smoothedMs - _lastTargetMs).abs() > 10) {
          _smoothedMs += (_lastTargetMs - _smoothedMs) * 0.3;
        } else {
          _smoothedMs = _lastTargetMs.toDouble();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MusicStyleOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timelinePositionMs != oldWidget.timelinePositionMs) {
      _lastTargetMs = widget.timelinePositionMs;
      _lastUpdateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = LyricsOverlayConfig.fromMap(widget.lyricsConfigData).copyWith(
      styleIndex: widget.lyricsConfigData == null
          ? widget.styleIndex
          : (widget.lyricsConfigData!['styleIndex'] as num?)?.toInt() ?? widget.styleIndex,
    );

    if (config.styleIndex == 0) {
      return const SizedBox.shrink();
    }

    final lines = _resolvedLyrics(
      widget.lyricsLrc,
      widget.title,
      widget.artist,
      widget.coverUrl,
    );
    final frame = _LyricsFrame.fromTimeline(lines, _smoothedMs.round());
    final theme = _lyricsThemes[config.themeIndex.clamp(0, _lyricsThemes.length - 1)];
    final font = _lyricsFonts[config.fontIndex.clamp(0, _lyricsFonts.length - 1)];

    return Align(
      alignment: _alignmentForAnchor(config.anchorIndex),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (frame.previousLine != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _contextLine(
                  frame.previousLine!.text,
                  theme,
                  font,
                  opacity: 0.34,
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  _transitionForStyle(config.styleIndex, child, animation),
              child: KeyedSubtree(
                key: ValueKey<String>(
                  '${config.styleIndex}_${frame.currentIndex}_${frame.currentLine.text}',
                ),
                child: _foregroundLine(frame, config, theme, font),
              ),
            ),
            if (frame.nextLine != null && config.styleIndex != 3)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _contextLine(
                  frame.nextLine!.text,
                  theme,
                  font,
                  opacity: 0.2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<LrcLine> _resolvedLyrics(
    String? lyrics,
    String title,
    String artist,
    String coverUrl,
  ) {
    final normalized = lyrics?.trim() ?? '';
    if (normalized.isNotEmpty) {
      final cached = MusicStyleOverlayWidget._lyricsCache[normalized];
      if (cached != null) {
        return cached;
      }
      final parsed = parseLrc(normalized);
      if (parsed.isNotEmpty) {
        MusicStyleOverlayWidget._lyricsCache[normalized] = parsed;
        return parsed;
      }
    }
    return _fallbackLyricsForTrack(
      MusicTrack(title, artist, '0:30', coverUrl, 'Lyrics', '', syncedLyrics: lyrics),
    );
  }

  Widget _foregroundLine(
    _LyricsFrame frame,
    LyricsOverlayConfig config,
    _LyricsThemePalette theme,
    _LyricsFontProfile font,
  ) {
    final baseStyle = _baseTextStyle(theme, font, 30);

    Widget lineChild;
    switch (config.styleIndex) {
      case 1:
        lineChild = _karaokeLine(frame, theme, font);
      case 2:
        lineChild = Text(
          frame.currentLine.text,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: theme.activeColor,
            fontSize: 32,
            shadows: <Shadow>[
              Shadow(
                color: theme.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        );
      case 3:
        lineChild = Text(
          frame.visibleSubstring,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: theme.activeColor,
            fontSize: 30,
            letterSpacing: 0.6 + font.letterSpacing,
          ),
        );
      default:
        lineChild = Text(
          frame.currentLine.text,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(color: theme.activeColor),
        );
    }

    return _wrapBackground(lineChild, config, theme);
  }

  Widget _karaokeLine(
    _LyricsFrame frame,
    _LyricsThemePalette theme,
    _LyricsFontProfile font,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6.0,
      runSpacing: 4.0,
      children: List.generate(frame.currentLine.words.length, (index) {
        final word = frame.currentLine.words[index];
        final start = word.startTime.inMilliseconds;
        final end = word.endTime.inMilliseconds;
        final currentMs = frame.timelineMs;

        final isActive = currentMs >= start && currentMs < end;
        final isPast = currentMs >= end;

        double scale = 1.0;
        Color color = theme.inactiveColor;
        double glowOpacity = 0.0;

        double timeSinceStart = (currentMs - start).toDouble();
        double timeSinceEnd = (currentMs - end).toDouble();

        if (isActive) {
          color = theme.activeColor;
          glowOpacity = 0.7;
          if (timeSinceStart < 150) {
            double p = timeSinceStart / 150.0;
            scale = 1.0 + 0.12 * math.sin(p * math.pi / 2);
          } else {
            scale = 1.12;
          }
        } else if (isPast) {
          color = theme.activeColor.withValues(alpha: 0.85);
          if (timeSinceEnd < 200) {
            double p = timeSinceEnd / 200.0;
            scale = 1.12 - 0.12 * math.sin(p * math.pi / 2);
          }
        }

        return Transform.scale(
          scale: scale,
          child: Text(
            word.text,
            style: _baseTextStyle(theme, font, 31).copyWith(
              color: color,
              shadows: <Shadow>[
                Shadow(
                  color: theme.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                if (glowOpacity > 0)
                  Shadow(
                    color: theme.glowColor.withValues(alpha: glowOpacity),
                    blurRadius: 16,
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _contextLine(
    String text,
    _LyricsThemePalette theme,
    _LyricsFontProfile font, {
    required double opacity,
  }) {
    return Opacity(
      opacity: opacity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _baseTextStyle(theme, font, 18).copyWith(
          color: theme.inactiveColor,
          fontSize: 18,
        ),
      ),
    );
  }

  TextStyle _baseTextStyle(
    _LyricsThemePalette theme,
    _LyricsFontProfile font,
    double size,
  ) {
    return TextStyle(
      color: theme.activeColor,
      fontSize: size,
      fontWeight: font.fontWeight,
      fontStyle: font.fontStyle,
      letterSpacing: font.letterSpacing,
      fontFamily: font.fontFamily,
      height: 1.08,
    );
  }

  Widget _wrapBackground(
    Widget child,
    LyricsOverlayConfig config,
    _LyricsThemePalette theme,
  ) {
    if (config.backgroundIndex == 0) {
      return child;
    }

    final decoration = switch (config.backgroundIndex) {
      2 => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      _ => BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.glowColor.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: decoration,
      child: child,
    );
  }

  Widget _transitionForStyle(
    int styleIndex,
    Widget child,
    Animation<double> animation,
  ) {
    switch (styleIndex) {
      case 1:
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
              ),
              child: child,
            ),
          ),
        );
      case 2:
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      default:
        return FadeTransition(opacity: animation, child: child);
    }
  }
}

class _LyricsFrame {
  final List<LrcLine> lines;
  final int currentIndex;
  final int timelineMs;

  const _LyricsFrame({
    required this.lines,
    required this.currentIndex,
    required this.timelineMs,
  });

  factory _LyricsFrame.fromTimeline(List<LrcLine> lines, int timelineMs) {
    if (lines.isEmpty) {
      return _LyricsFrame(lines: _fallbackLyricsForTrack(null), currentIndex: 0, timelineMs: timelineMs);
    }

    int index = 0;
    for (int i = 0; i < lines.length; i++) {
      if (timelineMs >= lines[i].time.inMilliseconds) {
        index = i;
      } else {
        break;
      }
    }

    return _LyricsFrame(
      lines: lines,
      currentIndex: index.clamp(0, lines.length - 1),
      timelineMs: timelineMs,
    );
  }

  LrcLine get currentLine => lines[currentIndex];

  LrcLine? get previousLine => currentIndex > 0 ? lines[currentIndex - 1] : null;

  LrcLine? get nextLine =>
      currentIndex + 1 < lines.length ? lines[currentIndex + 1] : null;

  double get lineProgress {
    final start = currentLine.time.inMilliseconds;
    final end = currentLine.endTime.inMilliseconds;
    if (end <= start) {
      return 1;
    }
    return ((timelineMs - start) / (end - start)).clamp(0, 1).toDouble();
  }

  double wordProgress(int wordIndex) {
    if (currentLine.words.isEmpty) {
      return lineProgress;
    }
    final word = currentLine.words[wordIndex];
    final start = word.startTime.inMilliseconds;
    final end = word.endTime.inMilliseconds;
    if (timelineMs <= start) {
      return 0;
    }
    if (timelineMs >= end) {
      return 1;
    }
    if (end <= start) {
      return 1;
    }
    return ((timelineMs - start) / (end - start)).clamp(0, 1).toDouble();
  }

  String get visibleSubstring {
    if (currentLine.text.isEmpty) {
      return '';
    }
    final charCount = (currentLine.text.length * lineProgress).ceil();
    return currentLine.text.substring(
      0,
      charCount.clamp(0, currentLine.text.length),
    );
  }
}

Alignment _alignmentForAnchor(int anchorIndex) {
  switch (anchorIndex) {
    case 0:
      return const Alignment(0, -0.72);
    case 2:
      return const Alignment(0, 0.72);
    default:
      return Alignment.center;
  }
}

List<LrcLine> _fallbackLyricsForTrack(MusicTrack? track) {
  final title = track?.title ?? 'KnockPost';
  final artist = track?.artist ?? 'Artist';
  return <LrcLine>[
    _inferredLine(Duration.zero, const Duration(seconds: 3), title),
    _inferredLine(
      const Duration(seconds: 3),
      const Duration(seconds: 6),
      artist,
    ),
    _inferredLine(
      const Duration(seconds: 6),
      const Duration(seconds: 10),
      title,
    ),
    _inferredLine(
      const Duration(seconds: 10),
      const Duration(seconds: 14),
      artist,
    ),
  ];
}

LrcLine _inferredLine(Duration start, Duration end, String text) {
  final normalized = text.trim().isEmpty ? 'KnockPost' : text.trim();
  return LrcLine(
    time: start,
    endTime: end,
    text: normalized,
    words: _inferWords(normalized, start, end),
  );
}

Duration _parseTimestampParts(String minutes, String seconds, String fractions) {
  final parsedMinutes = int.tryParse(minutes) ?? 0;
  final parsedSeconds = int.tryParse(seconds) ?? 0;
  final parsedFractions = int.tryParse(fractions) ?? 0;
  final milliseconds = fractions.length == 2
      ? parsedFractions * 10
      : parsedFractions;
  return Duration(
    minutes: parsedMinutes,
    seconds: parsedSeconds,
    milliseconds: milliseconds,
  );
}

String _stripWordTags(String rawText) {
  return rawText.replaceAll(_wordTimestampRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<LyricWordSegment> _extractWordSegments(
  String rawText,
  String normalizedText,
  Duration lineStart,
  Duration lineEnd,
) {
  final matches = _wordTimestampRegex.allMatches(rawText).toList();
  if (matches.isEmpty) {
    return _inferWords(normalizedText, lineStart, lineEnd);
  }

  final List<LyricWordSegment> words = <LyricWordSegment>[];
  for (int index = 0; index < matches.length; index++) {
    final match = matches[index];
    final start = _parseTimestampParts(
      match.group(1)!,
      match.group(2)!,
      match.group(3)!,
    );
    final nextStart = index + 1 < matches.length
        ? _parseTimestampParts(
            matches[index + 1].group(1)!,
            matches[index + 1].group(2)!,
            matches[index + 1].group(3)!,
          )
        : lineEnd;
    final chunk = rawText.substring(
      match.end,
      index + 1 < matches.length ? matches[index + 1].start : rawText.length,
    ).trim();
    if (chunk.isEmpty) {
      continue;
    }
    words.addAll(_inferWords(chunk, start, nextStart));
  }

  if (words.isEmpty) {
    return _inferWords(normalizedText, lineStart, lineEnd);
  }
  return words;
}

List<LyricWordSegment> _inferWords(
  String text,
  Duration start,
  Duration end,
) {
  final words = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (words.isEmpty) {
    return <LyricWordSegment>[
      LyricWordSegment(text: text, startTime: start, endTime: end),
    ];
  }

  final totalWeight = words.fold<int>(
    0,
    (sum, word) => sum + math.max<int>(1, word.length),
  );
  final totalMs = math.max<int>(180, end.inMilliseconds - start.inMilliseconds);

  int cursor = start.inMilliseconds;
  final List<LyricWordSegment> segments = <LyricWordSegment>[];
  for (int index = 0; index < words.length; index++) {
    final isLast = index == words.length - 1;
    final weight = math.max<int>(1, words[index].length);
    final lengthMs = isLast
        ? end.inMilliseconds - cursor
        : ((totalMs * weight) / totalWeight).round();
    final segmentEnd = isLast
        ? end.inMilliseconds
        : cursor + math.max<int>(120, lengthMs);
    segments.add(
      LyricWordSegment(
        text: words[index],
        startTime: Duration(milliseconds: cursor),
        endTime: Duration(milliseconds: segmentEnd),
      ),
    );
    cursor = segmentEnd;
  }
  return segments;
}
