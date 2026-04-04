import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/user_model.dart';

class ShareSheet extends StatelessWidget {
  final String url;
  final String username;
  final String caption;
  final String contentType;

  const ShareSheet({
    super.key,
    required this.url,
    required this.username,
    required this.caption,
    this.contentType = "glimpse",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),

          /// Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            "Share",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 20),

          /// Quick Share Row (DM avatars placeholder)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: allDemoUsers.length + 1,
              itemBuilder: (context, index) {
                if (index == allDemoUsers.length) {
                  // The "KnockPost" option at the end
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade800, width: 1),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "KnockPost",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Friends
                final user = allDemoUsers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade800, width: 1),
                        ),
                        child: ClipOval(
                          child: user.avatarAsset != null
                              ? Image.asset(user.avatarAsset!, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.primaries[index % Colors.primaries.length].shade700,
                                  alignment: Alignment.center,
                                  child: Text(
                                    user.displayName[0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.displayName.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Divider(color: Colors.grey.shade800, height: 1),

          const SizedBox(height: 8),

          /// Share Options Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(
                  context,
                  icon: Icons.link_rounded,
                  label: "Copy Link",
                  color: Colors.grey.shade300,
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: url),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text("Link copied to clipboard"),
                          ],
                        ),
                        backgroundColor: const Color(0xFF2D2D2D),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.share_rounded,
                  label: "Share via...",
                  color: Colors.blue.shade300,
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(
                      'Check out this $contentType by @$username on KnockPost!\n\n"$caption"\n\n$url',
                    );
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.flag_outlined,
                  label: "Report",
                  color: Colors.red.shade300,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade800.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
