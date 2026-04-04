import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';

const _kAccentBlue = Color(0xFF4361EE);

class CollagePickerScreen extends StatelessWidget {
  const CollagePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Collage', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0, // Square grids
        ),
        itemCount: 4, // 4 layout types
        itemBuilder: (context, index) {
          final icons = [
            Icons.grid_view_rounded,
            Icons.view_agenda_rounded,
            Icons.dashboard_rounded,
            Icons.view_compact_alt_rounded,
          ];
          
          final labels = [
            '2x2 Grid',
            'Vertical Split',
            '3 Photo Mix',
            '4 Vertical'
          ];

          return GestureDetector(
            onTap: () {
              KnockHaptics.tap();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collage renderer coming soon.')));
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icons[index], color: Colors.white70, size: 48),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kAccentBlue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(labels[index], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
