import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../utils/haptic_helper.dart';

class MediaPreviewScreen extends StatefulWidget {
  final File file;
  final Function(Uint8List bytes, String caption) onSend;

  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.onSend,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late Uint8List _currentBytes;
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.file.readAsBytesSync();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _openEditor() {
    KnockHaptics.tap();

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (editorContext) => ProImageEditor.memory(
          _currentBytes,
          configs: const ProImageEditorConfigs(
            cropRotateEditor: CropRotateEditorConfigs(
              style: CropRotateEditorStyle(
                cropCornerColor: Colors.white,
                cropCornerLength: 28,
                cropCornerThickness: 3,
              ),
            ),
          ),
          callbacks: ProImageEditorCallbacks(
            // IMPORTANT: ProImageEditor v12 auto-calls onCloseEditor AFTER
            // onImageEditingComplete finishes. So we must ONLY update bytes
            // here — never call Navigator.pop — else we get a double-pop that
            // also evicts the MediaPreviewScreen.
            onImageEditingComplete: (Uint8List bytes) async {
              if (mounted) {
                setState(() => _currentBytes = bytes);
              }
              // Do NOT pop here. The editor calls onCloseEditor automatically.
            },
            // onCloseEditor is called in two cases:
            //   (a) after onImageEditingComplete resolves (editing done)
            //   (b) user tapped the back/close button (discarding)
            // Either way, pop only the editor off the stack.
            onCloseEditor: (_) {
              if (Navigator.canPop(editorContext)) {
                Navigator.pop(editorContext);
              }
            },
          ),
        ),
      ),
    );
  }

  void _sendAndClose() {
    KnockHaptics.impact();
    final caption = _captionController.text.trim();
    // Call the callback BEFORE popping so parent has bytes before route is gone.
    widget.onSend(_currentBytes, caption);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back / Discard
                  GestureDetector(
                    onTap: () {
                      KnockHaptics.tap();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),

                  // Edit button  
                  GestureDetector(
                    onTap: _openEditor,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text("Edit",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Image Preview ─────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    _currentBytes,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // ── Bottom Send Bar ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Row(
                children: [
                  // Caption field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: "Add a caption...",
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Send button
                  GestureDetector(
                    onTap: _sendAndClose,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 24),
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
}
