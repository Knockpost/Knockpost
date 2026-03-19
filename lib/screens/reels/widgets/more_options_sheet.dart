import 'package:flutter/material.dart';

class MoreOptionsSheet extends StatelessWidget {
  final String username;

  const MoreOptionsSheet({
    super.key,
    required this.username,
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

          /// Options Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                /// Top row — primary actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _OptionCircle(
                      icon: Icons.visibility_off_outlined,
                      label: "Not\nInterested",
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          _buildSnackBar(
                            Icons.visibility_off_outlined,
                            "We'll show less content like this",
                          ),
                        );
                      },
                    ),
                    _OptionCircle(
                      icon: Icons.person_remove_outlined,
                      label: "Unfollow\n@$username",
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          _buildSnackBar(
                            Icons.person_remove_outlined,
                            "Unfollowed @$username",
                          ),
                        );
                      },
                    ),
                    _OptionCircle(
                      icon: Icons.repeat_rounded,
                      label: "Remix\nThis",
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                /// List options
                _OptionTile(
                  icon: Icons.info_outline_rounded,
                  label: "Why you're seeing this",
                  onTap: () => Navigator.pop(context),
                ),
                _OptionTile(
                  icon: Icons.subtitles_outlined,
                  label: "Manage captions",
                  onTap: () => Navigator.pop(context),
                ),
                _OptionTile(
                  icon: Icons.speed_rounded,
                  label: "Playback speed",
                  trailing: "1x",
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
                  label: "Report this reel",
                  isDestructive: true,
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
}

/// Circular icon option (top grid)
class _OptionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List-style option tile
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade400 : Colors.grey.shade200;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trailing!,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ),
            if (trailing == null)
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
