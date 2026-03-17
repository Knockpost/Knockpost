import 'package:flutter/material.dart';

class MediaPreview extends StatelessWidget {
  final List<String> mediaFiles;
  final VoidCallback onAddMedia;

  const MediaPreview({
    super.key,
    required this.mediaFiles,
    required this.onAddMedia,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddMedia,
      child: Container(
        height: 220,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: mediaFiles.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_photo_alternate_outlined, size: 40),
                  SizedBox(height: 8),
                  Text(
                    "Add photos or videos",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mediaFiles.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(mediaFiles[i]),
                  ),
                ),
              ),
      ),
    );
  }
}