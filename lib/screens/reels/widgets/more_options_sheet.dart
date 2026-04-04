import 'package:flutter/material.dart';
import '../../../utils/global_dismiss_state.dart';
import '../../../utils/global_post_state.dart';
import '../../../utils/haptic_helper.dart';

class MoreOptionsSheet extends StatelessWidget {
  final String userId;
  final String username;
  final String? postId;
  final bool isReel;
  final bool isOwner;

  const MoreOptionsSheet({
    super.key,
    required this.userId,
    required this.username,
    this.postId,
    this.isReel = false,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

          const SizedBox(height: 20),

          /// Options Grid / List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (isOwner) ...[
                  // Simple management for owner
                  _OptionTile(
                    icon: Icons.edit_note_rounded,
                    label: "Edit Post",
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildSnackBar(Icons.edit_note_rounded, "Edit mode coming soon"),
                      );
                    },
                  ),
                  _OptionTile(
                    icon: Icons.delete_outline_rounded,
                    label: "Delete Post",
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context);
                    },
                  ),
                ] else ...[
                  /// List options
                  _OptionTile(
                    icon: Icons.account_circle_outlined,
                    label: "About this account",
                    onTap: () => Navigator.pop(context),
                  ),
                  _OptionTile(
                    icon: Icons.block_outlined,
                    label: "Block @$username",
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _OptionTile(
                    icon: Icons.flag_outlined,
                    label: "Report this ${isReel ? 'glimpse' : 'post'}",
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  SnackBar _buildSnackBar(IconData icon, String text) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
      backgroundColor: const Color(0xFF2D2D2D),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      duration: const Duration(seconds: 2),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete post?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete this post? This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              if (postId != null) {
                GlobalPostState.delete(postId!);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Post deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// List-style option tile
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive 
                    ? Colors.red.withValues(alpha: 0.1) 
                    : Colors.grey.shade800.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red.shade400 : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red.shade400 : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade700,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
