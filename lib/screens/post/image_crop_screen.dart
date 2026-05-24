import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum CropAspect { square, portrait, portrait3x4 }

class ImageCropScreen extends StatefulWidget {
  final List<File> files;
  final String? initialCaption;
  final bool isGlimpse;
  final void Function(List<File> croppedFiles, double aspectRatio) onDone;

  const ImageCropScreen({
    super.key,
    required this.files,
    required this.onDone,
    this.initialCaption,
    this.isGlimpse = false,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen>
    with SingleTickerProviderStateMixin {
  CropAspect _aspect = CropAspect.portrait;
  bool _showGrid = true;
  bool _isLoading = true;
  bool _isCropping = false;
  int _currentIndex = 0;

  late final AnimationController _gridFadeCtrl;
  late List<_ImageTransform> _transforms;
  late List<Size?> _imageSizes;

  double _gestureBaseScale = 1.0;
  Offset _gestureBaseOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;
  Size _lastFrameSize = const Size(1080, 1350);

  @override
  void initState() {
    super.initState();
    _transforms = widget.files.map((_) => _ImageTransform()).toList();
    _imageSizes = List<Size?>.filled(widget.files.length, null);
    _gridFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _loadAllImageSizes();
  }

  @override
  void dispose() {
    _gridFadeCtrl.dispose();
    super.dispose();
  }

  double get _aspectRatio {
    switch (_aspect) {
      case CropAspect.square:
        return 1.0;
      case CropAspect.portrait:
        return 4.0 / 5.0;
      case CropAspect.portrait3x4:
        return 3.0 / 4.0;
    }
  }

  Size get _outputSize {
    const double outputWidth = 1080.0;
    return Size(outputWidth, (outputWidth / _aspectRatio).roundToDouble());
  }

  _ImageTransform get _currentTransform => _transforms[_currentIndex];

  Future<void> _loadAllImageSizes() async {
    for (int i = 0; i < widget.files.length; i++) {
      _imageSizes[i] = await _decodeImageSize(widget.files[i]);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<Size> _decodeImageSize(File file) async {
    final ImageProvider provider = FileImage(file);
    final Completer<Size> completer = Completer();
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      stream.removeListener(listener);
      completer.complete(size);
    }, onError: (Object exception, StackTrace? stackTrace) {
      stream.removeListener(listener);
      completer.completeError(exception);
    });
    stream.addListener(listener);
    return completer.future;
  }

  void _resetTransform() {
    HapticFeedback.lightImpact();
    setState(() {
      _transforms[_currentIndex] = _ImageTransform();
    });
  }

  void _toggleGrid() {
    HapticFeedback.selectionClick();
    setState(() => _showGrid = !_showGrid);
    if (_showGrid) {
      _gridFadeCtrl.forward();
    } else {
      _gridFadeCtrl.reverse();
    }
  }

  void _switchAspect(CropAspect aspect) {
    if (_aspect == aspect) return;
    HapticFeedback.selectionClick();
    setState(() {
      _aspect = aspect;
      _transforms = widget.files.map((_) => _ImageTransform()).toList();
    });
  }

  double _calculateIntelligentScale(Size frameSize, Size imageSize) {
    // Smart Initial Scale algorithm for portrait/long images:
    // 1. Maximize visible portrait content
    // 2. Fully cover the frame
    // 3. Avoid black edges
    // 4. Minimize initial crop
    final double widthScale = frameSize.width / imageSize.width;
    final double heightScale = frameSize.height / imageSize.height;

    // To prevent any black side areas and ensure safe full-frame coverage, 
    // we use the larger of the two scales. This automatically finds the exact 
    // minimum safe scale.
    return max(widthScale, heightScale);
  }

  void _clampOffset(_ImageTransform transform, Size frameSize) {
    final imageSize = _imageSizes[_currentIndex];
    if (imageSize == null) return;

    final double baseScale = _calculateIntelligentScale(frameSize, imageSize);

    final double drawnWidth = imageSize.width * baseScale * transform.scale;
    final double drawnHeight = imageSize.height * baseScale * transform.scale;
    final double maxDx = max(0.0, (drawnWidth - frameSize.width) / 2.0);
    final double maxDy = max(0.0, (drawnHeight - frameSize.height) / 2.0);

    transform.offset = Offset(
      transform.translateX.clamp(-maxDx, maxDx).toDouble(),
      transform.translateY.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  Rect _buildImageDrawRect({
    required Size frameSize,
    required Size imageSize,
    required _ImageTransform transform,
  }) {
    final double baseScale = _calculateIntelligentScale(frameSize, imageSize);

    final double displayScale = baseScale * transform.scale;
    final double drawWidth = imageSize.width * displayScale;
    final double drawHeight = imageSize.height * displayScale;

    return Rect.fromLTWH(
      frameSize.width / 2.0 + transform.translateX - drawWidth / 2.0,
      frameSize.height / 2.0 + transform.translateY - drawHeight / 2.0,
      drawWidth,
      drawHeight,
    );
  }

  Rect _scaleRect({
    required Rect rect,
    required Size fromSize,
    required Size toSize,
  }) {
    final double scaleX = toSize.width / fromSize.width;
    final double scaleY = toSize.height / fromSize.height;
    return Rect.fromLTWH(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );
  }

  Future<void> _cropAndProceed() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCropping = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final List<File> croppedFiles = [];

      for (int i = 0; i < widget.files.length; i++) {
        croppedFiles.add(
          await _cropSingleImage(widget.files[i], _transforms[i], tempDir, i),
        );
      }

      if (mounted) {
        widget.onDone(croppedFiles, _aspectRatio);
      }
    } catch (e) {
      debugPrint('Crop error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not process the image. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  Future<File> _cropSingleImage(
    File file,
    _ImageTransform transform,
    Directory tempDir,
    int index,
  ) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final ui.Image srcImage = frame.image;

    try {
      final Size imageSize = Size(
        srcImage.width.toDouble(),
        srcImage.height.toDouble(),
      );
      final Size outputSize = _outputSize;
      final int outputWidth = outputSize.width.round();
      final int outputHeight = outputSize.height.round();
      final Rect previewRect = _buildImageDrawRect(
        frameSize: _lastFrameSize,
        imageSize: imageSize,
        transform: transform,
      );
      final Rect outputRect = _scaleRect(
        rect: previewRect,
        fromSize: _lastFrameSize,
        toSize: outputSize,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, outputSize.width, outputSize.height),
      );

      canvas.drawRect(
        Rect.fromLTWH(0, 0, outputSize.width, outputSize.height),
        Paint()..color = const Color(0xFF000000),
      );

      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(0, 0, imageSize.width, imageSize.height),
        outputRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final ui.Image outputImage = await picture.toImage(
        outputWidth,
        outputHeight,
      );

      try {
        final ByteData? outputBytes = await outputImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (outputBytes == null) {
          throw StateError('Failed to encode cropped image.');
        }

        final outputFile = File(
          '${tempDir.path}/crop_${index}_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await outputFile.writeAsBytes(outputBytes.buffer.asUint8List());
        return outputFile;
      } finally {
        outputImage.dispose();
      }
    } finally {
      srcImage.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final frameSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        _lastFrameSize = frameSize;

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GestureDetector(
                            onScaleStart: (details) {
                              _gestureBaseScale = _currentTransform.scale;
                              _gestureBaseOffset = _currentTransform.offset;
                              _gestureStartFocal = details.focalPoint;
                            },
                            onScaleUpdate: (details) {
                              if (_isLoading) return;
                              setState(() {
                                final transform = _currentTransform;
                                
                                transform.scale =
                                    (_gestureBaseScale * details.scale)
                                        .clamp(1.0, 5.0)
                                        .toDouble();
                                transform.offset =
                                    _gestureBaseOffset +
                                    (details.focalPoint - _gestureStartFocal);
                                _clampOffset(transform, frameSize);
                              });
                            },
                            onScaleEnd: (_) {
                              setState(() {
                                _clampOffset(_currentTransform, frameSize);
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: Colors.black),
                                if (_isLoading)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  _buildCroppableImage(frameSize),
                                if (_showGrid)
                                  FadeTransition(
                                    opacity: _gridFadeCtrl,
                                    child: _buildGrid(),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.files.length > 1) _buildImageSelector(),
              _buildBottomControls(),
              const SizedBox(height: 12),
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
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'CROP & FRAME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: (_isCropping || _isLoading) ? null : _cropAndProceed,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: _isCropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'Next',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCroppableImage(Size frameSize) {
    final imageSize = _imageSizes[_currentIndex];
    if (imageSize == null) {
      return const SizedBox.shrink();
    }

    final Rect drawRect = _buildImageDrawRect(
      frameSize: frameSize,
      imageSize: imageSize,
      transform: _currentTransform,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: drawRect,
          child: Image.file(
            widget.files[_currentIndex],
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }

  Widget _buildImageSelector() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.files.length,
        itemBuilder: (context, index) {
          final bool isSelected = index == _currentIndex;
          return GestureDetector(
            onTap: () => setState(() => _currentIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 2.5 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  widget.files[index],
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _aspectChip(
                label: '1:1',
                icon: Icons.crop_square_rounded,
                isSelected: _aspect == CropAspect.square,
                onTap: () => _switchAspect(CropAspect.square),
              ),
              const SizedBox(width: 10),
              _aspectChip(
                label: '4:5',
                icon: Icons.crop_portrait_rounded,
                isSelected: _aspect == CropAspect.portrait,
                onTap: () => _switchAspect(CropAspect.portrait),
              ),
              const SizedBox(width: 10),
              _aspectChip(
                label: '3:4',
                icon: Icons.photo_size_select_large_rounded,
                isSelected: _aspect == CropAspect.portrait3x4,
                onTap: () => _switchAspect(CropAspect.portrait3x4),
              ),
            ],
          ),
          Row(
            children: [
              _actionButton(
                icon: _showGrid
                    ? Icons.grid_on_rounded
                    : Icons.grid_off_rounded,
                label: 'Grid',
                onTap: _toggleGrid,
              ),
              const SizedBox(width: 16),
              _actionButton(
                icon: Icons.refresh_rounded,
                label: 'Reset',
                onTap: _resetTransform,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aspectChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTransform {
  double scale = 1.0;
  double translateX = 0.0;
  double translateY = 0.0;

  _ImageTransform();

  Offset get offset => Offset(translateX, translateY);

  set offset(Offset value) {
    translateX = value.dx;
    translateY = value.dy;
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final double thirdWidth = size.width / 3;
    final double thirdHeight = size.height / 3;

    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      gridPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
