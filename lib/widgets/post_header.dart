import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/global_knock_state.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../screens/profile/widgets/creator_rank_badge.dart';
import '../utils/haptic_helper.dart';

class PostHeader extends StatefulWidget {
  final UserModel user;

  const PostHeader({super.key, required this.user});

  @override
  State<PostHeader> createState() => _PostHeaderState();
}

class _PostHeaderState extends State<PostHeader> {
  late ValueNotifier<KnockStatus> _globalNotifier;
  late KnockStatus _status;
  bool _showBlackFlash = false;

  @override
  void initState() {
    super.initState();
    _globalNotifier = GlobalKnockState.getNotifier(widget.user.id, widget.user.knockStatus);
    _status = _globalNotifier.value;
    _globalNotifier.addListener(_onGlobalStatusChanged);
  }

  void _onGlobalStatusChanged() {
    if (mounted && _status != _globalNotifier.value) {
      setState(() => _status = _globalNotifier.value);
    }
  }

  @override
  void didUpdateWidget(covariant PostHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _globalNotifier.removeListener(_onGlobalStatusChanged);
      _globalNotifier = GlobalKnockState.getNotifier(widget.user.id, widget.user.knockStatus);
      _status = _globalNotifier.value;
      _globalNotifier.addListener(_onGlobalStatusChanged);
    }
  }

  @override
  void dispose() {
    _globalNotifier.removeListener(_onGlobalStatusChanged);
    super.dispose();
  }

  void _toggleKnock() {
    KnockHaptics.tap();
    
    final isEffectivelyOpen = widget.user.accountType == AccountType.creator || 
                              widget.user.privacyType == PrivacyType.open;

    KnockStatus nextStatus = _status;
    
    switch (_status) {
      case KnockStatus.none:
        nextStatus = isEffectivelyOpen ? KnockStatus.knocked : KnockStatus.pending;
        _showBlackFlash = true;
        break;
      case KnockStatus.theyKnockedYou:
        nextStatus = KnockStatus.mutualKnocked;
        _showBlackFlash = true;
        break;
      case KnockStatus.pending:
      case KnockStatus.knocked:
      case KnockStatus.mutualKnocked:
        nextStatus = KnockStatus.none;
        break;
    }

    setState(() {
      _status = nextStatus;
    });
    
    // Broadcast status globally
    _globalNotifier.value = nextStatus;

    if (_showBlackFlash) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showBlackFlash = false);
      });
    }
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
          user: widget.user.copyWith(knockStatus: _status),
          posts: getDemoPostsForUser(widget.user.id),
          onKnockStatusChanged: (newStatus) {
            if (mounted) {
              setState(() => _status = newStatus);
            }
          },
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
    String label;

    switch (_status) {
      case KnockStatus.none:
        label = "Knock";
        break;
      case KnockStatus.theyKnockedYou:
        label = "Knock back";
        break;
      case KnockStatus.pending:
        label = "Pending";
        break;
      case KnockStatus.knocked:
      case KnockStatus.mutualKnocked:
        label = "Knocked";
        break;
    }

    if (_showBlackFlash) {
      bgColor = isDark ? Colors.white : Colors.black;
      textColor = isDark ? Colors.black : Colors.white;
    } else {
      bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2);
      textColor = isDark ? Colors.white : Colors.black;
    }

    final user = widget.user;
    final bool isCreator = user.accountType == AccountType.creator;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: user.avatarAsset != null
                      ? (user.avatarAsset!.startsWith('assets/')
                          ? AssetImage(user.avatarAsset!) as ImageProvider
                          : FileImage(File(user.avatarAsset!)))
                      : null,
                  child: user.avatarAsset == null
                      ? Icon(Icons.person, size: 18, color: Colors.grey.shade600)
                      : null,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          user.username,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.75,
                          ),
                        ),
                      ),
                      if (isCreator) ...[
                        const SizedBox(width: 5),
                        CreatorRankBadge(rank: user.rank, mini: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Knock / Knocked button ──
        if (!user.isOwnProfile) ...[
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
                child: Text(label),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // ── Three-dot menu ──
        GestureDetector(
          onTap: _showMoreOptions,
          child: const Icon(Icons.more_horiz),
        ),
      ],
    );
  }
}
