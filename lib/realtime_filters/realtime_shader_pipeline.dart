import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'realtime_filter_models.dart';

class RealtimeFilterProgramBundle {
  RealtimeFilterProgramBundle._(this._programs);

  final Map<RealtimeFilterType, ui.FragmentProgram> _programs;

  static Future<RealtimeFilterProgramBundle>? _cachedFuture;

  static Future<RealtimeFilterProgramBundle> load() {
    _cachedFuture ??= _loadPrograms();
    return _cachedFuture!;
  }

  ui.FragmentProgram programFor(RealtimeFilterType type) {
    return _programs[type]!;
  }

  static Future<RealtimeFilterProgramBundle> _loadPrograms() async {
    final entries = await Future.wait(
      realtimeFilterDefinitions.map((definition) async {
        final program = await ui.FragmentProgram.fromAsset(
          definition.shaderAssetKey,
        );
        return MapEntry<RealtimeFilterType, ui.FragmentProgram>(
          definition.type,
          program,
        );
      }),
    );
    return RealtimeFilterProgramBundle._(
      Map<RealtimeFilterType, ui.FragmentProgram>.fromEntries(entries),
    );
  }
}

class GpuFilteredCameraPreview extends StatelessWidget {
  final CameraController controller;
  final List<RealtimeFilterLayer> layers;
  final BoxFit fit;

  const GpuFilteredCameraPreview({
    super.key,
    required this.controller,
    required this.layers,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RealtimeFilterProgramBundle>(
      future: RealtimeFilterProgramBundle.load(),
      builder: (context, snapshot) {
        Widget preview = CameraPreview(controller);

        if (snapshot.hasData) {
          preview = RealtimeShaderPipeline(
            programs: snapshot.data!,
            layers: layers,
            child: preview,
          );
        }

        return FittedBox(
          fit: fit,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height:
                MediaQuery.sizeOf(context).width * controller.value.aspectRatio,
            child: preview,
          ),
        );
      },
    );
  }
}

class RealtimeShaderPipeline extends StatelessWidget {
  final RealtimeFilterProgramBundle programs;
  final List<RealtimeFilterLayer> layers;
  final Widget child;

  const RealtimeShaderPipeline({
    super.key,
    required this.programs,
    required this.layers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget current = child;

    for (final layer in layers) {
      if (!layer.enabled || layer.intensity <= 0.001) {
        continue;
      }

      current = _ShaderFilterStage(
        program: programs.programFor(layer.type),
        layer: layer,
        child: current,
      );
    }

    return current;
  }
}

class _ShaderFilterStage extends StatelessWidget {
  final ui.FragmentProgram program;
  final RealtimeFilterLayer layer;
  final Widget child;

  const _ShaderFilterStage({
    required this.program,
    required this.layer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final size = Size(width, height);
        final shader = program.fragmentShader();

        _configureShader(shader, size, layer);

        return ImageFiltered(
          imageFilter: ui.ImageFilter.shader(shader),
          child: CustomPaint(
            painter: const _ShaderCoveragePainter(),
            child: child,
          ),
        );
      },
    );
  }

  void _configureShader(
    ui.FragmentShader shader,
    Size size,
    RealtimeFilterLayer layer,
  ) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, layer.intensity);
    shader.setFloat(3, _auxiliaryUniformFor(layer));
  }

  double _auxiliaryUniformFor(RealtimeFilterLayer layer) {
    switch (layer.type) {
      case RealtimeFilterType.blackAndWhite:
        return layer.parameterValue('brightness');
      case RealtimeFilterType.losAngeles:
      case RealtimeFilterType.aestheticBlur:
      case RealtimeFilterType.lowLight:
      case RealtimeFilterType.ultraHd:
        return 0.0;
    }
  }
}

class _ShaderCoveragePainter extends CustomPainter {
  const _ShaderCoveragePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(1, 0, 0, 0)
      ..style = PaintingStyle.fill;
    canvas.drawPoints(ui.PointMode.points, <Offset>[
      Offset.zero,
      Offset(size.width - 1, 0),
      Offset(0, size.height - 1),
      Offset(size.width - 1, size.height - 1),
    ], paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
