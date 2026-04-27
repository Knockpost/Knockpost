import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import '../post/collage_picker_screen.dart';
import '../shared/music_picker_screen.dart';
import '../post/template_picker_screen.dart';
import '../post/custom_android_picker_sheet.dart';

// Brand colors (imported for consistency)
const _kAccentPurple = Color(0xFF9B5DE5);
const _kAccentBlue = Color(0xFF4361EE);

class WavesGallerySheet extends StatefulWidget {
  final bool showCreativeTools;
  const WavesGallerySheet({super.key, this.showCreativeTools = true});

  @override
  State<WavesGallerySheet> createState() => _WavesGallerySheetState();
}

class _WavesGallerySheetState extends State<WavesGallerySheet> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  bool _isMultiSelect = false;
  final List<AssetEntity> _selectedAssets = [];

  @override
  void initState() {
    super.initState();
    _fetchMedia();
  }

  Future<void> _fetchMedia() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) {
      if (mounted) setState(() { _isLoading = false; _hasPermission = false; });
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Images and Videos
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    AssetPathEntity? allAlbum;
    for (var a in albums) {
      if (a.isAll) {
        allAlbum = a;
        break;
      }
    }
    allAlbum ??= albums.isNotEmpty ? albums.first : null;

    if (allAlbum != null) {
      final List<AssetEntity> recentAssets = await allAlbum.getAssetListPaged(
        page: 0,
        size: 2000, 
      );
      if (mounted) {
        setState(() {
          _assets = recentAssets;
          _isLoading = false;
          _hasPermission = true;
        });
      }
    } else {
      if (mounted) setState(() { _isLoading = false; _hasPermission = true; });
    }
  }

  void _toggleSelection(AssetEntity asset) {
    KnockHaptics.tap();
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  Future<void> _finishSelection() async {
    if (_selectedAssets.isEmpty) return;
    KnockHaptics.tap();
    
    // We need to resolve AssetEntity to File before returning to the editor
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _kAccentPurple)),
    );

    List<File> files = [];
    for (var a in _selectedAssets) {
      final file = await a.file;
      if (file != null) files.add(file);
    }

    if (mounted) {
      Navigator.pop(context); // pop loading dialog
      Navigator.pop(context, files); // return files to caller
    }
  }

  Future<void> _pickSingle(AssetEntity asset) async {
    KnockHaptics.tap();
    final file = await asset.file;
    if (file != null && mounted) {
      Navigator.pop(context, [file]);
    }
  }

  void _showManageOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E), // Dark modal background
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Handle indicator
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Option 1: Select more photos
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  title: const Text('Select more photos', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context); // Close manage sheet
                    
                    // Native Android 14 call (only works if permission is explicitly 'Limited')
                    PhotoManager.presentLimited(); 
                    
                    // Immediately show our flawless 1:1 replica of the Android 14 System Picker
                    // to satisfy the user who expects it even when Full permissions are granted natively.
                    final result = await showModalBottomSheet<List<AssetEntity>>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.95,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          child: CustomAndroidPickerSheet(initialAssets: _assets),
                        ),
                      ),
                    );

                    // Re-inject items if the user completed the custom multi-select flow
                    if (result != null && result.isNotEmpty && mounted) {
                      setState(() {
                         _isMultiSelect = true;
                         for(var a in result) {
                             if(!_selectedAssets.contains(a)) _selectedAssets.add(a);
                         }
                      });
                    }
                  },
                ),
                
                // Option 2: Change settings
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  title: const Text('Change settings', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    PhotoManager.openSetting(); // Explicitly open OS app settings
                  },
                ),
                
                // Option 3: Cancel
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  title: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Substack/Insta base color
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── TOP HEADER ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            // ── INSTA-STYLE TOP ACTION ROW (only for Glimpse flow) ──
            if (widget.showCreativeTools)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionTopBtn('Templates', Icons.auto_awesome_mosaic_rounded, const Color(0xFFF15BB5), () {
                      KnockHaptics.tap();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatePickerScreen()));
                    }),
                    const SizedBox(width: 32),
                    _actionTopBtn('Collage', Icons.grid_view_rounded, _kAccentBlue, () {
                      KnockHaptics.tap();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CollagePickerScreen()));
                    }),
                  ],
                ),
              ),

            // ── RECENTS DROPDOWN & SELECT MODE ROW ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Recents',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
                    ],
                  ),
                  
                  // MULTI-SELECT TOGGLE
                  GestureDetector(
                    onTap: () {
                      KnockHaptics.tap();
                      setState(() {
                        _isMultiSelect = !_isMultiSelect;
                        if (!_isMultiSelect) _selectedAssets.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isMultiSelect ? Colors.white : Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded, 
                            color: _isMultiSelect ? Colors.black : Colors.white, 
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Select',
                            style: TextStyle(
                              color: _isMultiSelect ? Colors.black : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── PERMISSIONS TEXT (Mocked for reference) ──
            if (_hasPermission && !Platform.isIOS) // Usually iOS has limited permission warnings natively
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "You've given Knockpost access to a select number of photos and videos.",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        KnockHaptics.tap();
                        _showManageOptionsSheet();
                      },
                      child: const Text(
                        "Manage",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // ── GRID GALLERY VIEW ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kAccentPurple))
                  : !_hasPermission
                      ? Center(
                          child: Text(
                            'Please grant photo permissions\nin settings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        )
                      : Stack(
                          children: [
                            GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                              ),
                              itemCount: _assets.length + 1, // +1 for the camera button
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // CAMERA BUTTON TILE
                                  return GestureDetector(
                                    onTap: () => Navigator.pop(context), // Just go back to camera screen
                                    child: Container(
                                      color: const Color(0xFF1E1E1E),
                                      child: const Center(
                                        child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 30),
                                      ),
                                    ),
                                  );
                                }

                                final asset = _assets[index - 1];
                                final isSelected = _selectedAssets.contains(asset);
                                final selIndex = _selectedAssets.indexOf(asset) + 1;

                                return GestureDetector(
                                  onTap: () {
                                    if (_isMultiSelect) {
                                      _toggleSelection(asset);
                                    } else {
                                      _pickSingle(asset);
                                    }
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Native Thumbnail
                                      FutureBuilder<Uint8List?>(
                                        future: asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
                                        builder: (_, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return Container(color: Colors.white10);
                                          }
                                          if (snapshot.hasData && snapshot.data != null) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                              gaplessPlayback: true,
                                            );
                                          }
                                          return Container(color: Colors.white10);
                                        },
                                      ),

                                      // Video Duration Badge
                                      if (asset.type == AssetType.video)
                                        Positioned(
                                          bottom: 4,
                                          right: 6,
                                          child: Text(
                                            _formatDuration(asset.videoDuration),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12, // Slightly larger for readability
                                              fontWeight: FontWeight.w600, // Distinct from iOS default
                                              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                                            ),
                                          ),
                                        ),

                                      // Custom Checkbox Overlay
                                      if (_isMultiSelect)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected ? _kAccentBlue : Colors.black26,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: isSelected
                                                ? Center(
                                                    child: Text(
                                                      '$selIndex',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        
                                        // Dimmer selected overlay
                                        if (isSelected)
                                          Container(color: Colors.black.withValues(alpha: 0.3)),
                                    ],
                                  ),
                                );
                              },
                            ),
                            
                            // Bottom Action Bar when multi-selecting
                            if (_isMultiSelect && _selectedAssets.isNotEmpty)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.only(
                                    left: 16, right: 16, top: 12,
                                    bottom: MediaQuery.of(context).padding.bottom + 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    border: const Border(top: BorderSide(color: Colors.white10)),
                                  ),
                                  child: SafeArea(
                                    top: false,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_selectedAssets.length} Selected',
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        GestureDetector(
                                          onTap: _finishSelection,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            child: const Text(
                                              'Next',
                                              style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
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
      ),
    );
  }

  // ── Helper UI Components ──

  String _formatDuration(Duration d) {
    if (d.inSeconds == 0) return '';
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    return "${d.inMinutes}:$twoDigitSeconds"; // usually single digit minutes is preferred, but this matches Insta close enough
  }

  Widget _actionTopBtn(String label, IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Dark grey box
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
