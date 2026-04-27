import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../utils/haptic_helper.dart';
import 'image_crop_screen.dart';
import 'media_editor_screen.dart';
import 'video_post_editor_screen.dart';

class UnifiedMediaPickerScreen extends StatefulWidget {
  final String? initialCaption;
  final bool isGlimpse;

  const UnifiedMediaPickerScreen({
    super.key,
    this.initialCaption,
    this.isGlimpse = false,
  });

  @override
  State<UnifiedMediaPickerScreen> createState() =>
      _UnifiedMediaPickerScreenState();
}

class _UnifiedMediaPickerScreenState extends State<UnifiedMediaPickerScreen> {
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selectedAssets = [];

  AssetEntity? _focusedAsset;
  VideoPlayerController? _previewController;
  int _previewToken = 0;

  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isMultiSelect = false;
  bool _isOpeningNext = false;
  bool _isPreviewReady = false;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _disposePreviewController();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && permission != PermissionState.limited) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasPermission = false;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    AssetPathEntity? album;
    for (final candidate in albums) {
      if (candidate.isAll) {
        album = candidate;
        break;
      }
    }
    album ??= albums.isNotEmpty ? albums.first : null;

    final fetched = album == null
        ? <AssetEntity>[]
        : await album.getAssetListPaged(page: 0, size: 2000);

    if (!mounted) return;
    setState(() {
      _assets
        ..clear()
        ..addAll(fetched);
      _hasPermission = true;
      _isLoading = false;
      _focusedAsset = fetched.isNotEmpty ? fetched.first : null;
    });

    if (_focusedAsset != null) {
      await _focusAsset(_focusedAsset!);
    }
  }

  Future<void> _focusAsset(AssetEntity asset) async {
    if (!mounted) return;
    final token = ++_previewToken;

    setState(() {
      _focusedAsset = asset;
      _isPreviewReady = asset.type != AssetType.video;
    });

    if (asset.type != AssetType.video) {
      await _disposePreviewController();
      return;
    }

    final file = await asset.file;
    if (!mounted || token != _previewToken || file == null) return;

    await _disposePreviewController();
    final controller = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _previewController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted || token != _previewToken) return;
      setState(() => _isPreviewReady = true);
    } catch (_) {
      if (!mounted || token != _previewToken) return;
      setState(() => _isPreviewReady = false);
    }
  }

  Future<void> _disposePreviewController() async {
    final controller = _previewController;
    _previewController = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  void _toggleSelectMode() {
    KnockHaptics.tap();
    if (_isMultiSelect) {
      setState(() {
        _isMultiSelect = false;
        _selectedAssets.clear();
      });
      return;
    }

    AssetEntity? nextFocus = _focusedAsset;
    if (nextFocus != null && nextFocus.type == AssetType.video) {
      nextFocus = _assets.cast<AssetEntity?>().firstWhere(
        (asset) => asset?.type == AssetType.image,
        orElse: () => null,
      );
    }

    setState(() {
      _isMultiSelect = true;
      _selectedAssets.clear();
      _focusedAsset = nextFocus;
      _isPreviewReady = nextFocus?.type != AssetType.video;
    });

    if (nextFocus != null) {
      _focusAsset(nextFocus);
    }
  }

  Future<void> _onAssetTap(AssetEntity asset) async {
    if (_isMultiSelect) {
      if (asset.type != AssetType.image) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video posts support one video at a time.'),
          ),
        );
        return;
      }

      KnockHaptics.tap();
      setState(() {
        if (_selectedAssets.any((selected) => selected.id == asset.id)) {
          _selectedAssets.removeWhere((selected) => selected.id == asset.id);
        } else {
          _selectedAssets.add(asset);
        }
      });
      await _focusAsset(asset);
      return;
    }

    KnockHaptics.tap();
    await _focusAsset(asset);
  }

  Future<List<File>> _resolveFiles(List<AssetEntity> assets) async {
    final resolved = <File>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) {
        resolved.add(file);
      }
    }
    return resolved;
  }

  Future<void> _openSelectedFlow() async {
    if (_isOpeningNext) return;

    final selection = _isMultiSelect
        ? List<AssetEntity>.from(_selectedAssets)
        : (_focusedAsset == null
              ? <AssetEntity>[]
              : <AssetEntity>[_focusedAsset!]);
    if (selection.isEmpty) return;

    setState(() => _isOpeningNext = true);
    try {
      if (!_isMultiSelect && selection.first.type == AssetType.video) {
        final file = await selection.first.file;
        if (file == null || !mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPostEditorScreen(
              videoFile: file,
              initialCaption: widget.initialCaption,
              isGlimpse: widget.isGlimpse,
            ),
          ),
        );
        return;
      }

      final files = await _resolveFiles(selection);
      if (files.isEmpty || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageCropScreen(
            files: files,
            initialCaption: widget.initialCaption,
            isGlimpse: widget.isGlimpse,
            onDone: (croppedFiles, aspectRatio) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaEditorScreen(
                    files: croppedFiles,
                    initialCaption: widget.initialCaption,
                    aspectRatio: aspectRatio,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningNext = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildPreview() {
    final asset = _focusedAsset;
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!_hasPermission) {
      return Center(
        child: Text(
          'Allow access to your gallery to create a post.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (asset == null) {
      return Center(
        child: Text(
          'No photos or videos found.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      );
    }

    if (asset.type == AssetType.video) {
      if (_previewController != null &&
          _previewController!.value.isInitialized &&
          _isPreviewReady) {
        final size = _previewController!.value.size;
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(_previewController!),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _previewBadge(
                icon: Icons.videocam_rounded,
                label: _formatDuration(asset.videoDuration),
              ),
            ),
          ],
        );
      }

      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(1200, 1500)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(color: Colors.white.withValues(alpha: 0.04));
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }

  Widget _previewBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTile(AssetEntity asset) {
    final isFocused = _focusedAsset?.id == asset.id;
    final selectionIndex = _selectedAssets.indexWhere(
      (selected) => selected.id == asset.id,
    );
    final isSelected = selectionIndex >= 0;
    final isVideo = asset.type == AssetType.video;
    final isDisabledVideo = _isMultiSelect && isVideo;

    return GestureDetector(
      onTap: () => _onAssetTap(asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
              const ThumbnailSize.square(420),
            ),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return Container(color: Colors.white.withValues(alpha: 0.06));
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
          if (isDisabledVideo)
            Container(color: Colors.black.withValues(alpha: 0.4)),
          if (isFocused && !_isMultiSelect)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          if (_isMultiSelect)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.35),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: isSelected
                    ? Center(
                        child: Text(
                          '${selectionIndex + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          if (isVideo)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatDuration(asset.videoDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _isMultiSelect
        ? _selectedAssets.isNotEmpty
        : _focusedAsset != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'New Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: hasSelection && !_isOpeningNext
                        ? _openSelectedFlow
                        : null,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.2,
                      ),
                      disabledForegroundColor: Colors.black.withValues(
                        alpha: 0.45,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isOpeningNext
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.white.withValues(alpha: 0.04)),
                      _buildPreview(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recents',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Photos and videos together, just like the main post flow.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleSelectMode,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _isMultiSelect
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isMultiSelect
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: _isMultiSelect ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Select',
                            style: TextStyle(
                              color: _isMultiSelect
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    )
                  : !_hasPermission
                  ? Center(
                      child: Text(
                        'Please allow photo access in settings.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        2,
                        0,
                        2,
                        MediaQuery.of(context).padding.bottom + 12,
                      ),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                      itemCount: _assets.length,
                      itemBuilder: (context, index) {
                        return _buildAssetTile(_assets[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
