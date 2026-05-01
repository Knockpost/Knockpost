import 'package:flutter/material.dart';
import '../../../utils/global_dismiss_state.dart';
import '../../../utils/global_post_state.dart';
import '../../../utils/haptic_helper.dart';
import '../../../services/post_service.dart';
import '../../../services/database_service.dart';
import '../../../services/current_user_service.dart';

class MoreOptionsSheet extends StatelessWidget {
  final String userId;
  final String username;
  final String? postId;
  final bool isReel;
  final bool isOwner;
  final String postTypeName;

  const MoreOptionsSheet({
    super.key,
    required this.userId,
    required this.username,
    this.postId,
    this.isReel = false,
    this.isOwner = false,
    this.postTypeName = "Post",
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final handleColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              color: handleColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 16),

          /// Options Grid / List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (isOwner) ...[
                  // Simple management for owner
                  _OptionTile(
                    icon: Icons.edit_note_rounded,
                    label: "Edit $postTypeName",
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildSnackBar(context, Icons.edit_note_rounded, "Edit mode coming soon"),
                      );
                    },
                  ),
                  _OptionTile(
                    icon: Icons.delete_outline_rounded,
                    label: "Delete $postTypeName",
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context);
                    },
                  ),
                ] else ...[
                  /// List options
                  _OptionTile(
                    icon: Icons.info_outline_rounded,
                    label: "About this account",
                    onTap: () => Navigator.pop(context),
                  ),
                  _OptionTile(
                    icon: Icons.visibility_off_outlined,
                    label: "Hide this ${postTypeName.toLowerCase()}",
                    onTap: () => Navigator.pop(context),
                  ),
                  _OptionTile(
                    icon: Icons.flag_outlined,
                    label: "Report",
                    onTap: () => Navigator.pop(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Divider(
                      color: isDark ? Colors.white12 : Colors.black12,
                      height: 1,
                    ),
                  ),
                  _OptionTile(
                    icon: Icons.block_outlined,
                    label: "Block @$username",
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      final myUid = CurrentUserService.instance.currentUser?.id;
                      if (myUid != null) {
                        DatabaseService.instance.blockUser(myUid: myUid, targetUid: userId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Blocked @$username")),
                        );
                      }
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

  SnackBar _buildSnackBar(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 18),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      duration: const Duration(seconds: 2),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete ${postTypeName.toLowerCase()}?", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text(
          "Are you sure you want to delete this ${postTypeName.toLowerCase()}? This action cannot be undone.",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              if (postId != null) {
                GlobalPostState.delete(postId!);
                PostService.instance.deletePost(postId!);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("$postTypeName deleted")),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : Colors.black87;
    final defaultIconBg = isDark ? Colors.grey.shade800.withValues(alpha: 0.4) : Colors.grey.shade200;
    final destructiveIconBg = isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive ? destructiveIconBg : defaultIconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red.shade500 : (isDark ? Colors.white : Colors.black87),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red.shade500 : defaultTextColor,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
