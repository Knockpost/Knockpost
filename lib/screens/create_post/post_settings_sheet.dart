import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import 'friend_picker_screen.dart';

// ─── Audience Model ─────────────────────────────────────────────────────────

enum PostAudience {
  myFriends,
  myFriendsExcept,
  onlyShareWith,
}

extension PostAudienceLabel on PostAudience {
  String get label {
    switch (this) {
      case PostAudience.myFriends:
        return 'My Friends';
      case PostAudience.myFriendsExcept:
        return 'My Friends Except…';
      case PostAudience.onlyShareWith:
        return 'Only Share With…';
    }
  }

  String get subtitle {
    switch (this) {
      case PostAudience.myFriends:
        return 'All your connections can see this';
      case PostAudience.myFriendsExcept:
        return 'Hidden from specific friends';
      case PostAudience.onlyShareWith:
        return 'Visible only to chosen people';
    }
  }

  IconData get icon {
    switch (this) {
      case PostAudience.myFriends:
        return Icons.people_rounded;
      case PostAudience.myFriendsExcept:
        return Icons.person_remove_rounded;
      case PostAudience.onlyShareWith:
        return Icons.lock_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case PostAudience.myFriends:
        return const Color(0xFF4ADE80); // green
      case PostAudience.myFriendsExcept:
        return const Color(0xFFFBBF24); // amber
      case PostAudience.onlyShareWith:
        return const Color(0xFF60A5FA); // blue
    }
  }
}

// ─── Result Model ────────────────────────────────────────────────────────────

class PostSettingsResult {
  final PostDuration duration;
  final PostAudience audience;
  final List<String>? selectedFriendIds;

  const PostSettingsResult({
    required this.duration,
    required this.audience,
    this.selectedFriendIds,
  });
}

// ─── Sheet Widget ────────────────────────────────────────────────────────────

class PostSettingsSheet extends StatefulWidget {
  final bool isGlimpse;
  final PostDuration initialDuration;
  final PostAudience initialAudience;

  const PostSettingsSheet({
    super.key,
    this.isGlimpse = false,
    this.initialDuration = PostDuration.h24,
    this.initialAudience = PostAudience.myFriends,
  });

  @override
  State<PostSettingsSheet> createState() => _PostSettingsSheetState();
}

class _PostSettingsSheetState extends State<PostSettingsSheet>
    with SingleTickerProviderStateMixin {
  late PostDuration _duration;
  late PostAudience _audience;
  List<String> _selectedFriendsExcept = [];
  List<String> _selectedOnlyShareWith = [];
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration;
    _audience = widget.initialAudience;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _confirm() {
    KnockHaptics.tap();
    Navigator.pop(
      context,
      PostSettingsResult(
        duration: _duration, 
        audience: _audience,
        selectedFriendIds: _audience == PostAudience.myFriendsExcept
            ? _selectedFriendsExcept
            : _audience == PostAudience.onlyShareWith
                ? _selectedOnlyShareWith
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFAFAFA);
    final divider = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE);

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Handle ──────────────────────────────────────
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Title ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Post Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── SECTION 1: Post Duration ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                    icon: Icons.timer_outlined,
                    label: 'Post Duration',
                    subtitle:
                        'How long should this ${widget.isGlimpse ? 'Glimpse' : 'post'} be visible?',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _buildDurationOption(
                    value: PostDuration.h24,
                    title: '24 Hours',
                    subtitle: 'Disappears after one day',
                    icon: Icons.timelapse_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDurationOption(
                    value: PostDuration.h36,
                    title: '36 Hours',
                    subtitle: 'Extended temporary visibility',
                    icon: Icons.update_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDurationOption(
                    value: PostDuration.lifetime,
                    title: 'Lifetime',
                    subtitle: 'Stays on your profile permanently',
                    icon: Icons.all_inclusive_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Divider(height: 1, color: divider),
            const SizedBox(height: 24),

            // ─── SECTION 2: Audience (WhatsApp style) ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                    icon: Icons.visibility_outlined,
                    label: 'Who can see this?',
                    subtitle: 'Choose your audience like a status update',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  ...PostAudience.values.map((aud) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildAudienceOption(aud, isDark),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── CONFIRM BUTTON ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? Colors.white : const Color(0xFF0E0E0E),
                    foregroundColor:
                        isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Duration Card ────────────────────────────────────────────────────────

  Widget _buildDurationOption({
    required PostDuration value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _duration == value;
    final accent = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : Colors.transparent;

    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        setState(() => _duration = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.2))
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.2)),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: isDark ? Colors.black : Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Audience Card (WhatsApp style) ──────────────────────────────────────

  Widget _buildAudienceOption(PostAudience aud, bool isDark) {
    final isSelected = _audience == aud;
    final accent = aud.accentColor;

    return GestureDetector(
      onTap: () async {
        KnockHaptics.tap();
        if (aud == PostAudience.myFriendsExcept) {
          final result = await showFriendPickerScreen(
            context,
            title: aud.label,
            subtitle: aud.subtitle,
            accentColor: accent,
            initiallySelected: _selectedFriendsExcept,
          );
          if (result != null) {
            setState(() {
              _audience = aud;
              _selectedFriendsExcept = result;
            });
          }
        } else if (aud == PostAudience.onlyShareWith) {
          final result = await showFriendPickerScreen(
            context,
            title: aud.label,
            subtitle: aud.subtitle,
            accentColor: accent,
            initiallySelected: _selectedOnlyShareWith,
          );
          if (result != null) {
            setState(() {
              _audience = aud;
              _selectedOnlyShareWith = result;
            });
          }
        } else {
          setState(() => _audience = aud);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: isDark ? 0.12 : 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.45)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.18)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                aud.icon,
                size: 18,
                color: isSelected
                    ? accent
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aud.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    aud.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Custom radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? accent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.2)),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper: Show the sheet ──────────────────────────────────────────────────

Future<PostSettingsResult?> showPostSettingsSheet(
  BuildContext context, {
  bool isGlimpse = false,
  PostDuration initialDuration = PostDuration.h24,
  PostAudience initialAudience = PostAudience.myFriends,
}) {
  return showModalBottomSheet<PostSettingsResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => PostSettingsSheet(
      isGlimpse: isGlimpse,
      initialDuration: initialDuration,
      initialAudience: initialAudience,
    ),
  );
}
