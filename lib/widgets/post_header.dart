import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../utils/haptic_helper.dart';

class PostHeader extends StatefulWidget {
  const PostHeader({super.key});

  @override
  State<PostHeader> createState() => _PostHeaderState();
}

class _PostHeaderState extends State<PostHeader> {
  bool _isKnocked = false;
  bool _showBlackFlash = false;

  void _toggleKnock() {
    KnockHaptics.tap();
    if (_isKnocked) {
      // Already knocked — just un-knock
      setState(() => _isKnocked = false);
      return;
    }

    // First tap: flash black for 1 second, then settle to normal "Knocked"
    setState(() {
      _isKnocked = true;
      _showBlackFlash = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _showBlackFlash = false);
      }
    });
  }

  void _showMoreOptions() {
    KnockHaptics.impact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Menu items ──
                _buildMenuItem(
                  icon: Icons.visibility_outlined,
                  label: "Interested",
                  onTap: () => Navigator.pop(context),
                ),
                _buildMenuItem(
                  icon: Icons.not_interested_outlined,
                  label: "Not interested",
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.account_circle_outlined,
                  label: "About this account",
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.report_outlined,
                  label: "Report",
                  color: Colors.red,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherProfileScreen(
          user: demoCreatorUser,
          posts: demoOwnPosts,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87);

    return InkWell(
      onTap: () { KnockHaptics.selection(); onTap(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: effectiveColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine button colors
    Color bgColor;
    Color textColor;

    if (!_isKnocked) {
      // Default state
      bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2);
      textColor = isDark ? Colors.white : Colors.black;
    } else if (_showBlackFlash) {
      // 1-second flash after first tap
      bgColor = isDark ? Colors.white : Colors.black;
      textColor = isDark ? Colors.black : Colors.white;
    } else {
      // Settled "Knocked" state — reverts to original look but text stays "Knocked"
      bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2);
      textColor = isDark ? Colors.white : Colors.black;
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey,
                ),
                SizedBox(width: 10),
                Text(
                  "username",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Knock / Knocked button ──
        GestureDetector(
          onTap: _toggleKnock,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              child: Text(_isKnocked ? "Knocked" : "Knock"),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ── Three-dot menu ──
        GestureDetector(
          onTap: _showMoreOptions,
          child: const Icon(Icons.more_horiz),
        ),
      ],
    );
  }
}
