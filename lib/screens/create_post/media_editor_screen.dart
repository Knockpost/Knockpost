import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'final_post_screen.dart';

class MediaEditorScreen extends StatefulWidget {
  final List<File> files;
  
  const MediaEditorScreen({super.key, required this.files});

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  // For now, we edit the first file. Collage/Carousel support can be expanded later.
  late File _currentFile;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.files.first;
  }

  Future<void> _onEditingComplete(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final newFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await newFile.writeAsBytes(bytes);
    
    if (!mounted) return;
    
    // Now push to final post screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FinalPostScreen(
          files: [newFile], 
          // If we had multiple files, we'd add them here
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      _currentFile,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (bytes) async {
          await _onEditingComplete(bytes);
        },
        onCloseEditor: (EditorMode mode) => Navigator.pop(context),
      ),
    );
  }
}
