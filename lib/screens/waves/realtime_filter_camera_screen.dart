import 'dart:io';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../realtime_filters/realtime_filter_controller.dart';
import '../../realtime_filters/realtime_filter_models.dart';
import '../../realtime_filters/realtime_shader_pipeline.dart';
import '../../utils/haptic_helper.dart';
import '../post/media_editor_screen.dart';
import 'waves_gallery_sheet.dart';

class RealtimeFilterCameraScreen extends StatefulWidget {
  const RealtimeFilterCameraScreen({super.key});

  @override
  State<RealtimeFilterCameraScreen> createState() =>
      _RealtimeFilterCameraScreenState();
}

class _RealtimeFilterCameraScreenState
    extends State<RealtimeFilterCameraScreen> {
  final RealtimeFilterController _filterController = RealtimeFilterController();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const <CameraDescription>[];

  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  bool _isCameraLoading = true;
  bool _isRecording = false;
  bool _showComposer = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }

      if (cameras.isEmpty) {
        setState(() => _isCameraLoading = false);
        return;
      }

      _cameras = cameras;
      await _configureCamera(cameras[_cameraIndex]);
    } catch (error) {
      debugPrint('Realtime filter camera init error: $error');
      if (!mounted) {
        return;
      }
      setState(() => _isCameraLoading = false);
      _showMessage('Could not access the device camera.');
    }
  }

  Future<void> _configureCamera(CameraDescription description) async {
    final previousController = _cameraController;
    final nextController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
    );

    setState(() => _isCameraLoading = true);
    _cameraController = null;

    await previousController?.dispose();

    try {
      await nextController.initialize();
      await nextController.setFlashMode(_flashMode);

      if (!mounted) {
        await nextController.dispose();
        return;
      }

      setState(() {
        _cameraController = nextController;
        _isCameraLoading = false;
      });
    } catch (error) {
      debugPrint('Realtime filter camera setup error: $error');
      await nextController.dispose();
      if (!mounted) {
        return;
      }
      setState(() => _isCameraLoading = false);
      _showMessage('Could not configure the selected camera.');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final nextMode = controller.value.flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;

    try {
      await controller.setFlashMode(nextMode);
      if (!mounted) {
        return;
      }
      KnockHaptics.tap();
      setState(() => _flashMode = nextMode);
    } catch (_) {
      _showMessage('Flash is not available on this camera.');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isRecording || _isCameraLoading) {
      return;
    }

    KnockHaptics.tap();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _configureCamera(_cameras[_cameraIndex]);
  }

  Future<void> _openGallery() async {
    KnockHaptics.tap();
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WavesGallerySheet(showCreativeTools: false),
    );

    if (!mounted || result is! List<File> || result.isEmpty) {
      return;
    }

    _openEditor(result);
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isCameraLoading) {
      return;
    }

    try {
      KnockHaptics.tap();
      final photo = await controller.takePicture();
      if (!mounted) {
        return;
      }
      _openEditor(<File>[File(photo.path)]);
    } catch (error) {
      debugPrint('Realtime filter photo capture error: $error');
      _showMessage('Could not capture a photo.');
    }
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo ||
        _isCameraLoading) {
      return;
    }

    try {
      KnockHaptics.tap();
      await controller.prepareForVideoRecording();
      await controller.startVideoRecording();
      if (!mounted) {
        return;
      }
      setState(() => _isRecording = true);
    } catch (error) {
      debugPrint('Realtime filter record start error: $error');
      _showMessage('Could not start recording.');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) {
      return;
    }

    try {
      final video = await controller.stopVideoRecording();
      if (!mounted) {
        return;
      }
      KnockHaptics.tap();
      setState(() => _isRecording = false);
      _openEditor(<File>[File(video.path)]);
    } catch (error) {
      debugPrint('Realtime filter record stop error: $error');
      if (!mounted) {
        return;
      }
      setState(() => _isRecording = false);
      _showMessage('Could not finish recording.');
    }
  }

  void _openEditor(List<File> files) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaEditorScreen(files: files, initialCaption: ''),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: controller == null || !controller.value.isInitialized
            ? _buildLoadingState()
            : Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _filterController,
                      builder: (context, _) {
                        return GpuFilteredCameraPreview(
                          controller: controller,
                          layers: _filterController.layers.toList(),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: _buildEdgeGradient(alignmentTop: true),
                  ),
                  Positioned.fill(
                    child: _buildEdgeGradient(alignmentTop: false),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: <Widget>[
                          _glassIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Realtime Filter Camera',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'GPU passes stacked over the live camera preview.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(top: 128, left: 16, child: _buildSideRail()),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: _showComposer ? 360 : 132,
                    child: AnimatedBuilder(
                      animation: _filterController,
                      builder: (context, _) => _buildActiveStackSummary(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _showComposer ? 0.0 : 1.0,
                      child: IgnorePointer(
                        ignoring: _showComposer,
                        child: _buildBottomControls(),
                      ),
                    ),
                  ),
                  if (_showComposer) _buildComposerPanel(),
                  if (_isCameraLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.26),
                        child: const Center(
                          child: KnockpostLoadingIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const KnockpostLoadingIndicator(),
          const SizedBox(height: 16),
          Text(
            _isCameraLoading
                ? 'Loading realtime GPU camera...'
                : 'No camera found',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeGradient({required bool alignmentTop}) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignmentTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: alignmentTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: alignmentTop ? 0.72 : 0.9),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideRail() {
    final hasFilters = _filterController.hasActiveFilters;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _railButton(
                icon: Icons.auto_awesome_rounded,
                active: _showComposer,
                onTap: () {
                  KnockHaptics.tap();
                  setState(() => _showComposer = !_showComposer);
                },
              ),
              _railButton(
                icon: _flashMode == FlashMode.off
                    ? Icons.flash_off_rounded
                    : Icons.flash_on_rounded,
                active: _flashMode != FlashMode.off,
                onTap: _toggleFlash,
              ),
              _railButton(
                icon: Icons.layers_clear_rounded,
                active: hasFilters,
                onTap: () {
                  KnockHaptics.tap();
                  _filterController.reset();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStackSummary() {
    final activeLayers = _filterController.activeLayers;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    activeLayers.isEmpty
                        ? 'GPU stack idle'
                        : 'GPU stack ${activeLayers.length} pass${activeLayers.length == 1 ? '' : 'es'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    activeLayers.isEmpty ? 'Preview clean' : 'Realtime ready',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (activeLayers.isEmpty)
                Text(
                  'Enable one or more filters to stack them over the camera preview.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                    height: 1.35,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeLayers
                      .map((layer) {
                        final definition = realtimeFilterDefinitionFor(
                          layer.type,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                definition.icon,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${definition.shortTitle} ${(layer.intensity * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _isRecording ? 'Recording video...' : 'Tap photo  •  Hold video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                _glassSquareButton(
                  icon: Icons.photo_library_rounded,
                  onTap: _openGallery,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _capturePhoto,
                  onLongPress: _startRecording,
                  onLongPressUp: _stopRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 3.2,
                      ),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _isRecording ? 38 : 64,
                        height: _isRecording ? 38 : 64,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.redAccent : Colors.white,
                          shape: _isRecording
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: _isRecording
                              ? BorderRadius.circular(14)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _glassSquareButton(
                  icon: Icons.flip_camera_ios_rounded,
                  onTap: _flipCamera,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.sizeOf(context).height * 0.58,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withValues(alpha: 0.78),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Modular Filter Pipeline',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toggle and stack GPU passes. The pipeline order follows the list below.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          KnockHaptics.tap();
                          _filterController.reset();
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _filterController,
                    builder: (context, _) {
                      final layers = _filterController.layers;
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        itemCount: layers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final layer = layers[index];
                          final definition = realtimeFilterDefinitionFor(
                            layer.type,
                          );
                          return _buildFilterCard(
                            index: index,
                            definition: definition,
                            layer: layer,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required int index,
    required RealtimeFilterDefinition definition,
    required RealtimeFilterLayer layer,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(definition.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      definition.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      definition.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: layer.enabled,
                onChanged: (value) {
                  KnockHaptics.tap();
                  _filterController.toggle(definition.type, value);
                },
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white38,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _filterSliderRow(
            label: 'Intensity',
            value: layer.intensity,
            minLabel: '0',
            maxLabel: '1',
            onChanged: (value) =>
                _filterController.setIntensity(definition.type, value),
          ),
          for (final parameter in definition.parameters) ...<Widget>[
            const SizedBox(height: 10),
            _filterSliderRow(
              label: parameter.label,
              value: layer.parameterValue(parameter.id),
              min: parameter.min,
              max: parameter.max,
              minLabel: parameter.min.toStringAsFixed(2),
              maxLabel: parameter.max.toStringAsFixed(2),
              onChanged: (value) => _filterController.setParameter(
                definition.type,
                parameter.id,
                value,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterSliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
    required String minLabel,
    required String maxLabel,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          minLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayColor: Colors.white.withValues(alpha: 0.08),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        Text(
          maxLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _glassSquareButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _railButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Icon(
          icon,
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.78),
          size: 26,
        ),
      ),
    );
  }
}
