import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/media_transform.dart';
import 'media_transform_utils.dart';

enum VideoPostAspect { square, portrait, landscape }

extension VideoPostAspectX on VideoPostAspect {
  String get label {
    switch (this) {
      case VideoPostAspect.square:
        return '1:1';
      case VideoPostAspect.portrait:
        return '4:5';
      case VideoPostAspect.landscape:
        return '16:9';
    }
  }

  double get ratio {
    switch (this) {
      case VideoPostAspect.square:
        return 1.0;
      case VideoPostAspect.portrait:
        return 4 / 5;
      case VideoPostAspect.landscape:
        return 16 / 9;
    }
  }

  Size get outputSize {
    switch (this) {
      case VideoPostAspect.square:
        return const Size(720, 720);
      case VideoPostAspect.portrait:
        return const Size(720, 900);
      case VideoPostAspect.landscape:
        return const Size(1280, 720);
    }
  }
}

enum VideoPostTextFont { classic, serif, mono }

extension VideoPostTextFontX on VideoPostTextFont {
  String get label {
    switch (this) {
      case VideoPostTextFont.classic:
        return 'Classic';
      case VideoPostTextFont.serif:
        return 'Serif';
      case VideoPostTextFont.mono:
        return 'Mono';
    }
  }

  String? get fontFamily {
    switch (this) {
      case VideoPostTextFont.classic:
        return null;
      case VideoPostTextFont.serif:
        return 'serif';
      case VideoPostTextFont.mono:
        return 'monospace';
    }
  }
}

// VideoPostTransform removed — using shared MediaTransform instead.

enum CinematicEffect { none, warm, cool, vintage, blur, glow, grain }

class VideoPostEffectAdjustments {
  final double brightness;
  final double contrast;
  final double warmth;
  final CinematicEffect filter;

  const VideoPostEffectAdjustments({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.warmth = 0.0,
    this.filter = CinematicEffect.none,
  });

  VideoPostEffectAdjustments copyWith({
    double? brightness,
    double? contrast,
    double? warmth,
    CinematicEffect? filter,
  }) {
    return VideoPostEffectAdjustments(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      warmth: warmth ?? this.warmth,
      filter: filter ?? this.filter,
    );
  }

  bool get isIdentity =>
      brightness.abs() < 0.001 &&
      (contrast - 1.0).abs() < 0.001 &&
      warmth.abs() < 0.001 &&
      filter == CinematicEffect.none;
}

class VideoPostTextOverlay {
  final String text;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final Color color;
  final VideoPostTextFont font;
  final Duration? startTime;
  final Duration? endTime;

  const VideoPostTextOverlay({
    required this.text,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color = Colors.white,
    this.font = VideoPostTextFont.classic,
    this.startTime,
    this.endTime,
  });

  VideoPostTextOverlay copyWith({
    String? text,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    Color? color,
    VideoPostTextFont? font,
    Duration? startTime,
    Duration? endTime,
  }) {
    return VideoPostTextOverlay(
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      color: color ?? this.color,
      font: font ?? this.font,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
      'color': color.toARGB32(),
      'font': font.name,
      'startTime': startTime?.inMilliseconds,
      'endTime': endTime?.inMilliseconds,
    };
  }
}

class VideoPostStickerOverlay {
  final String emoji;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final Duration? startTime;
  final Duration? endTime;

  const VideoPostStickerOverlay({
    required this.emoji,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.startTime,
    this.endTime,
  });
}


class VideoPostSourceInfo {
  final Size size;
  final Duration duration;
  final bool hasAudio;

  const VideoPostSourceInfo({
    required this.size,
    required this.duration,
    required this.hasAudio,
  });
}

class VideoPostExportRequest {
  final File inputVideo;
  final Size sourceSize;
  final Size previewFrameSize;
  final Size outputSize;
  final MediaTransform transform;
  final Duration trimStart;
  final Duration trimEnd;
  final Duration coverTime;
  final bool sourceHasAudio;
  final double originalAudioVolume;
  final File? musicFile;
  final Duration musicTrimStart;
  final double musicVolume;
  final File? customCoverImage;
  final List<VideoPostTextOverlay> textOverlays;
  final List<VideoPostStickerOverlay> stickerOverlays;

  final VideoPostEffectAdjustments effectAdjustments;

  const VideoPostExportRequest({
    required this.inputVideo,
    required this.sourceSize,
    required this.previewFrameSize,
    required this.outputSize,
    required this.transform,
    required this.trimStart,
    required this.trimEnd,
    required this.coverTime,
    required this.sourceHasAudio,
    required this.originalAudioVolume,
    this.musicFile,
    this.musicTrimStart = Duration.zero,
    this.musicVolume = 0.0,
    this.customCoverImage,
    this.textOverlays = const [],
    this.stickerOverlays = const [],

    this.effectAdjustments = const VideoPostEffectAdjustments(),
  });
}

class VideoPostExportResult {
  final File videoFile;
  final File coverFile;
  final Duration clipDuration;

  const VideoPostExportResult({
    required this.videoFile,
    required this.coverFile,
    required this.clipDuration,
  });
}

class ScheduledOverlayData {
  final File file;
  final Duration? start;
  final Duration? end;
  ScheduledOverlayData(this.file, this.start, this.end);
}

class VideoPostProcessing {
  static Future<VideoPostSourceInfo> probeSource(
    File videoFile, {
    Size? fallbackSize,
    Duration? fallbackDuration,
  }) async {
    final session = await FFprobeKit.getMediaInformation(videoFile.path);
    final information = session.getMediaInformation();
    final allProperties = information?.getAllProperties();
    final format = allProperties is Map ? allProperties['format'] : null;
    final durationSeconds = _parseDouble(
      format is Map ? format['duration'] : null,
    );
    final streams = information?.getStreams() ?? const [];

    bool hasAudio = false;
    int? width;
    int? height;

    for (final stream in streams) {
      final type = stream.getType();
      if (type == 'audio') {
        hasAudio = true;
      } else if (type == 'video') {
        width ??= stream.getWidth();
        height ??= stream.getHeight();
      }
    }

    final resolvedWidth = fallbackSize?.width ?? width?.toDouble() ?? 1080;
    final resolvedHeight = fallbackSize?.height ?? height?.toDouble() ?? 1920;
    final resolvedDuration = durationSeconds != null
        ? Duration(milliseconds: (durationSeconds * 1000).round())
        : (fallbackDuration ?? Duration.zero);

    return VideoPostSourceInfo(
      size: Size(resolvedWidth, resolvedHeight),
      duration: resolvedDuration,
      hasAudio: hasAudio,
    );
  }

  // buildPreviewDrawRect, clampOffset, and buildSourceCropRect removed — delegated to MediaTransformUtils

  static TextStyle buildTextStyle({
    required VideoPostTextOverlay overlay,
    required Size frameSize,
  }) {
    final safeWidth = frameSize.width <= 0 ? 1080.0 : frameSize.width;
    final fontSize = max(18.0, safeWidth * 0.07) * overlay.scale;

    return TextStyle(
      color: overlay.color,
      fontSize: fontSize,
      fontWeight: overlay.font == VideoPostTextFont.mono
          ? FontWeight.w700
          : FontWeight.w700,
      fontFamily: overlay.font.fontFamily,
      height: 1.1,
      shadows: const [
        Shadow(color: Color(0xB3000000), blurRadius: 10, offset: Offset(0, 2)),
      ],
    );
  }
  
  static Size measureTextOverlay({
    required VideoPostTextOverlay overlay,
    required Size frameSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: overlay.text,
        style: buildTextStyle(overlay: overlay, frameSize: frameSize),
      ),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: frameSize.width * 0.82);
    return painter.size;
  }

  static Offset clampTextPosition({
    required VideoPostTextOverlay overlay,
    required Size frameSize,
    required Offset proposedTopLeft,
  }) {
    final textSize = measureTextOverlay(overlay: overlay, frameSize: frameSize);
    return Offset(
      proposedTopLeft.dx.clamp(0.0, max(0.0, frameSize.width - textSize.width)),
      proposedTopLeft.dy.clamp(
        0.0,
        max(0.0, frameSize.height - textSize.height),
      ),
    );
  }

  static TextStyle _buildStickerStyle(VideoPostStickerOverlay overlay, Size frameSize) {
    final safeWidth = frameSize.width <= 0 ? 1080.0 : frameSize.width;
    return TextStyle(
      fontSize: max(32.0, safeWidth * 0.15) * overlay.scale,
      shadows: const [Shadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))],
    );
  }
  


  static Future<VideoPostExportResult> exportEditedVideo(
    VideoPostExportRequest request, {
    void Function(double)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final videoOutput = File('${tempDir.path}\\knockpost_video_$timestamp.mp4');
    final cropRect = _normalizedCropRect(
      raw: MediaTransformUtils.buildSourceCropRect(
        canvasSize: request.previewFrameSize,
        mediaSize: request.sourceSize,
        transform: request.transform,
      ),
      sourceSize: request.sourceSize,
    );
    final clipLengthSeconds = max(
      0.1,
      request.trimEnd.inMilliseconds > request.trimStart.inMilliseconds
          ? (request.trimEnd.inMilliseconds - request.trimStart.inMilliseconds) / 1000
          : request.trimEnd.inMilliseconds / 1000,
    );
    final clipDuration = Duration(
      milliseconds: (clipLengthSeconds * 1000).round(),
    );

    final overlayFiles = await _renderAllOverlays(
      tempDir: tempDir,
      timestamp: timestamp,
      request: request,
    );

    final hasMusic =
        request.musicFile != null &&
        request.musicFile!.existsSync() &&
        request.musicVolume > 0.01;
    final hasOriginalAudio =
        request.sourceHasAudio && request.originalAudioVolume > 0.01;

    int nextInputIndex = 1;
    int? musicInputIndex;
    if (hasMusic) {
      musicInputIndex = nextInputIndex++;
    }

    List<int> overlayInputIndices = [];
    for (int i = 0; i < overlayFiles.length; i++) {
      overlayInputIndices.add(nextInputIndex++);
    }

    final commandBuffer = StringBuffer()
      ..write('-y ')
      ..write('-i ${_quote(request.inputVideo.path)} ');

    if (hasMusic) {
      final mStart = request.musicTrimStart.inMilliseconds / 1000;
      commandBuffer.write('-discard:v all -stream_loop -1 -ss $mStart -i ${_quote(request.musicFile!.path)} ');
    }

    for (var o in overlayFiles) {
      commandBuffer.write('-loop 1 -i ${_quote(o.file.path)} ');
    }

    final filterComplex = _buildFilterComplex(
      request: request,
      cropRect: cropRect,
      clipLengthSeconds: clipLengthSeconds,
      musicInputIndex: musicInputIndex,
      overlayFiles: overlayFiles,
      overlayInputIndices: overlayInputIndices,
      includeOriginalAudio: hasOriginalAudio,
      includeMusic: hasMusic,
    );

    commandBuffer
      ..write('-filter_complex ${_quote(filterComplex)} ')
      ..write('-map [vout] ');

    if (hasOriginalAudio || hasMusic) {
      commandBuffer
        ..write('-map [aout] ')
        ..write('-c:a aac -b:a 192k ');
    } else {
      commandBuffer.write('-an ');
    }

    commandBuffer
      ..write('-c:v libx264 -preset ultrafast -tune fastdecode -crf 26 -threads 8 -pix_fmt yuv420p ')
      ..write('-movflags +faststart ')
      ..write('-max_muxing_queue_size 1024 ')
      ..write('-t ${clipLengthSeconds.toStringAsFixed(3)} ') // Force exact length, prevents infinite loop hang
      ..write(_quote(videoOutput.path));

    await _run(
      commandBuffer.toString(),
      onProgress: onProgress,
      clipLengthSeconds: clipLengthSeconds,
    );

    final coverFile = request.customCoverImage != null
        ? await _processCustomCover(
            imageFile: request.customCoverImage!,
            outputSize: request.outputSize,
            tempDir: tempDir,
            timestamp: timestamp,
          )
        : await _extractCoverFrame(
            videoFile: videoOutput,
            outputSize: request.outputSize,
            tempDir: tempDir,
            timestamp: timestamp,
            time: request.coverTime - request.trimStart,
          );

    return VideoPostExportResult(
      videoFile: videoOutput,
      coverFile: coverFile,
      clipDuration: clipDuration,
    );
  }

  static Future<List<ScheduledOverlayData>> _renderAllOverlays({
    required Directory tempDir,
    required int timestamp,
    required VideoPostExportRequest request,
  }) async {
    List<ScheduledOverlayData> results = [];
    final outputSize = request.outputSize;

    // We render each text overlay individually so it can overlap over time
    for (int i = 0; i < request.textOverlays.length; i++) {
      final t = request.textOverlays[i];
      final file = await _renderSingleElement(
        tempDir: tempDir, timestamp: '${timestamp}_txt_$i', size: outputSize,
        draw: (canvas, size) {
           final baseStyle = buildTextStyle(overlay: t, frameSize: size);
           _drawTextPainter(canvas, size, baseStyle, t.text, t.x, t.y, t.rotation, 3);
        }
      );
      if (file != null) results.add(ScheduledOverlayData(file, t.startTime, t.endTime));
    }

    for (int i = 0; i < request.stickerOverlays.length; i++) {
      final s = request.stickerOverlays[i];
      final file = await _renderSingleElement(
        tempDir: tempDir, timestamp: '${timestamp}_stk_$i', size: outputSize,
        draw: (canvas, size) {
           final baseStyle = _buildStickerStyle(s, size);
           _drawTextPainter(canvas, size, baseStyle, s.emoji, s.x, s.y, s.rotation, 1);
        }
      );
      if (file != null) results.add(ScheduledOverlayData(file, s.startTime, s.endTime));
    }



    return results;
  }

  static void _drawTextPainter(Canvas canvas, Size size, TextStyle style, String text, double xRatio, double yRatio, double rotation, int maxLines, {bool centerAlign = false}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: centerAlign ? TextAlign.center : TextAlign.left,
      maxLines: maxLines,
    );
    painter.layout(maxWidth: size.width * 0.85);

    double targetX = xRatio * size.width;
    double targetY = yRatio * size.height;

    if (centerAlign) {
      targetX -=  painter.width / 2;
      targetY -=  painter.height / 2;
    }

    final cx = targetX + painter.width / 2;
    final cy = targetY + painter.height / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    canvas.translate(-cx, -cy);
    painter.paint(canvas, Offset(targetX, targetY));
    canvas.restore();
  }

  static Future<File?> _renderSingleElement({
    required Directory tempDir,
    required String timestamp,
    required Size size,
    required Function(Canvas, Size) draw,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas, size);

    final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;

    final file = File('${tempDir.path}\\knockpost_overlay_$timestamp.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  static String _buildFilterComplex({
    required VideoPostExportRequest request,
    required Rect cropRect,
    required double clipLengthSeconds,
    required int? musicInputIndex,
    required List<ScheduledOverlayData> overlayFiles,
    required List<int> overlayInputIndices,
    required bool includeOriginalAudio,
    required bool includeMusic,
  }) {
    final filters = <String>[
      'trim=start=${_secondsString(request.trimStart)}:duration=${clipLengthSeconds.toStringAsFixed(3)}',
      'setpts=PTS-STARTPTS',
      'crop=${cropRect.width.round()}:${cropRect.height.round()}:${cropRect.left.round()}:${cropRect.top.round()}',
      'scale=${request.outputSize.width.round()}:${request.outputSize.height.round()}:flags=fast_bilinear',
      'setsar=1',
    ];

    if (!request.effectAdjustments.isIdentity || overlayFiles.isNotEmpty) {
      filters.add('format=rgba');
    }

    final eff = request.effectAdjustments;
    if (eff.filter == CinematicEffect.blur) {
      filters.add('boxblur=luma_radius=12:luma_power=3');
    } else if (eff.filter == CinematicEffect.glow) {
      filters.add('split=2[a][b];[a]boxblur=20:5[a2];[a2][b]blend=all_mode=screen');
    } else if (eff.filter == CinematicEffect.warm) {
      filters.add('colorbalance=rs=0.15:gm=0.0:bs=-0.15');
    } else if (eff.filter == CinematicEffect.cool) {
      filters.add('colorbalance=rs=-0.15:gm=0.0:bs=0.15');
    } else if (eff.filter == CinematicEffect.vintage) {
      filters.add('colorbalance=rs=0.2:gm=0.1:bs=-0.2,eq=contrast=1.1:saturation=0.9,noise=alls=15:allf=t+u');
    } else if (eff.filter == CinematicEffect.grain) {
      filters.add('noise=alls=25:allf=t+u,eq=contrast=1.05');
    } else if (!eff.isIdentity) {
      filters.add(_buildGeqFilter(eff));
    }

    final buffer = StringBuffer()..write('[0:v]${filters.join(',')}[basev];');
    
    String currentOut = '[basev]';
    if (overlayFiles.isEmpty) {
       buffer.write('[basev]format=yuv420p[vout]');
    } else {
       for (int i = 0; i < overlayFiles.length; i++) {
         final o = overlayFiles[i];
         final inputIdx = overlayInputIndices[i];
         final isLast = i == overlayFiles.length - 1;
         final newOut = isLast ? '[vout1]' : '[vtmp$i]';
         
         String eb = '';
         if (o.start != null && o.end != null) {
            eb = ":enable='between(t,${_secondsString(o.start!)},${_secondsString(o.end!)})'";
         }
         
         buffer.write('$currentOut[$inputIdx:v]overlay=0:0:format=auto$eb$newOut;');
         currentOut = newOut;
       }
       if (overlayFiles.isNotEmpty) {
         buffer.write('${currentOut}format=yuv420p[vout]');
       }
    }

    if (includeOriginalAudio) {
      buffer.write(
        ';[0:a]atrim=start=${_secondsString(request.trimStart)}:duration=${clipLengthSeconds.toStringAsFixed(3)},asetpts=PTS-STARTPTS,volume=${request.originalAudioVolume.toStringAsFixed(3)},aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[orig]',
      );
    }

    if (includeMusic && musicInputIndex != null) {
      buffer.write(
        ';[$musicInputIndex:a]atrim=duration=${clipLengthSeconds.toStringAsFixed(3)},asetpts=PTS-STARTPTS,volume=${request.musicVolume.toStringAsFixed(3)},aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[music]',
      );
    }

    if (includeOriginalAudio && includeMusic) {
      buffer.write(
        ';[orig][music]amix=inputs=2:duration=longest:dropout_transition=0,volume=2[aout]',
      );
    } else if (includeOriginalAudio) {
      buffer.write(';[orig]anull[aout]');
    } else if (includeMusic) {
      buffer.write(';[music]anull[aout]');
    }

    return buffer.toString();
  }

  static String _buildGeqFilter(VideoPostEffectAdjustments adjustments) {
    // simplified for brevity fallback since cinematic types handle main looks
    return "eq=brightness=${(adjustments.brightness*2).toStringAsFixed(3)}:contrast=${adjustments.contrast.toStringAsFixed(3)}";
  }

  static Future<File> _processCustomCover({
    required File imageFile,
    required Size outputSize,
    required Directory tempDir,
    required int timestamp,
  }) async {
    final outputFile = File('${tempDir.path}\\knockpost_cover_$timestamp.jpg');
    final filter =
        'scale=${outputSize.width.round()}:${outputSize.height.round()}:force_original_aspect_ratio=increase,'
        'crop=${outputSize.width.round()}:${outputSize.height.round()},'
        'setsar=1';
    final command =
        '-y -i ${_quote(imageFile.path)} -vf ${_quote(filter)} -frames:v 1 '
        '${_quote(outputFile.path)}';
    await _run(command);
    return outputFile;
  }

  static Future<File> _extractCoverFrame({
    required File videoFile,
    required Size outputSize,
    required Directory tempDir,
    required int timestamp,
    required Duration time,
  }) async {
    final outputFile = File('${tempDir.path}\\knockpost_cover_$timestamp.jpg');
    final clampedTime = time.isNegative ? Duration.zero : time;
    final command =
        '-y -ss ${_secondsString(clampedTime)} -i ${_quote(videoFile.path)} '
        '-frames:v 1 -q:v 2 ${_quote(outputFile.path)}';
    await _run(command);
    return outputFile;
  }

  static Future<void> _run(
    String command, {
    void Function(double)? onProgress,
    double clipLengthSeconds = 0,
  }) async {
    final completer = Completer<void>();
    await FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final output = await session.getOutput();
          completer.completeError(StateError(output ?? 'FFmpeg command failed.'));
        } else {
          completer.complete();
        }
      },
      null, // LogCallback
      (stat) {
        if (onProgress != null && clipLengthSeconds > 0) {
          final timeStr = stat.getTime(); // Time in ms
          if (timeStr > 0) {
            double prog = (timeStr / 1000) / clipLengthSeconds;
            onProgress(prog.clamp(0.0, 1.0));
          }
        }
      },
    );
    await completer.future;
  }

  static String _quote(String value) => '"${value.replaceAll('"', r'\"')}"';

  static String _secondsString(Duration value) =>
      (value.inMilliseconds / 1000).toStringAsFixed(3);

  static double? _parseDouble(Object? value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static Rect _normalizedCropRect({
    required Rect raw,
    required Size sourceSize,
  }) {
    int width = raw.width.round();
    int height = raw.height.round();
    int left = raw.left.floor();
    int top = raw.top.floor();

    width = width.clamp(2, sourceSize.width.round());
    height = height.clamp(2, sourceSize.height.round());
    left = left.clamp(0, max(0, sourceSize.width.round() - width));
    top = top.clamp(0, max(0, sourceSize.height.round() - height));

    if (width.isOdd) width -= 1;
    if (height.isOdd) height -= 1;
    if (left.isOdd) left = max(0, left - 1);
    if (top.isOdd) top = max(0, top - 1);

    if (left + width > sourceSize.width.round()) {
      left = max(0, sourceSize.width.round() - width);
    }
    if (top + height > sourceSize.height.round()) {
      top = max(0, sourceSize.height.round() - height);
    }

    return Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }
}
