import 'dart:typed_data';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class CustomAndroidPickerSheet extends StatefulWidget {
  final List<AssetEntity> initialAssets;

  const CustomAndroidPickerSheet({super.key, required this.initialAssets});

  @override
  State<CustomAndroidPickerSheet> createState() => _CustomAndroidPickerSheetState();
}

class _CustomAndroidPickerSheetState extends State<CustomAndroidPickerSheet> {
  final List<AssetEntity> _selectedAssets = [];
  bool _showBanner = true;
  int _tabIndex = 0; // 0 = Photos, 1 = Collections

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Android 14 System Modal Background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // ── Top Drag Handle ──
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // ── Authentic Android 14 Segmented Control ──
              Container(
                width: 280,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    _buildSegment(0, Icons.photo_outlined, 'Photos'),
                    _buildSegment(1, Icons.folder_outlined, 'Collections'),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── System Disclaimer Banner ──
          if (_showBanner)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF1B4D90), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage photos and videos Knockpost has access to',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _showBanner = false);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(
                        color: Color(0xFF1B4D90),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: widget.initialAssets.isEmpty
                ? const Center(child: KnockpostLoadingIndicator())
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: widget.initialAssets.length,
                    itemBuilder: (context, index) {
                      final asset = widget.initialAssets[index];
                      final isSelected = _selectedAssets.contains(asset);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAssets.remove(asset);
                            } else {
                              _selectedAssets.add(asset);
                            }
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FutureBuilder<Uint8List?>(
                              future: asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
                              builder: (_, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Container(color: Colors.grey.shade300);
                                }
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return Container(color: Colors.grey.shade300);
                              },
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.blue.withValues(alpha: 0.2), // Authentic Android selection tint
                              ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? const Color(0xFF1B4D90) : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedAssets.isNotEmpty ? _buildActionDock() : null,
    );
  }

  Widget _buildSegment(int index, IconData icon, String label) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF27437D) : Colors.transparent, // Authentic Android Blue
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade800),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedAssets.length}',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Preview',
                    style: TextStyle(
                      color: Color(0xFF1B4D90),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    // Inject selected assets directly back to the WavesGallerySheet and trigger app logic
                    Navigator.pop(context, _selectedAssets);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27437D), // Authentic Android Done Button Color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
