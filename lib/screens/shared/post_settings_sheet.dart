import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import 'friend_picker_screen.dart';

// ─── Audience Model ─────────────────────────────────────────────────────────

enum PostAudience { myFriends, myFriendsExcept, onlyShareWith }

extension PostAudienceLabel on PostAudience {
  String get label {
    switch (this) {
      case PostAudience.myFriends:
        return 'Everyone';
      case PostAudience.myFriendsExcept:
        return 'Everyone Except…';
      case PostAudience.onlyShareWith:
        return 'Only Share With…';
    }
  }

  String get subtitle {
    switch (this) {
      case PostAudience.myFriends:
        return 'Everyone / Connections can see this';
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
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
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

  int get _durationIndex {
    switch (_duration) {
      case PostDuration.h24:
        return 0;
      case PostDuration.h36:
        return 1;
      case PostDuration.lifetime:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFAFAFA);

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
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
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

            const SizedBox(height: 28),

            // ─── SECTION 1: Post Duration — Segmented Toggle ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section label
                  Text(
                    'DURATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Premium segmented toggle ──
                  _buildDurationToggle(isDark),
                  const SizedBox(height: 10),
                  // Subtitle below toggle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _getDurationSubtitle(),
                      key: ValueKey(_duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── Divider ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),

            const SizedBox(height: 24),

            // ─── SECTION 2: Audience ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUDIENCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...PostAudience.values.map(
                    (aud) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAudienceOption(aud, isDark),
                    ),
                  ),
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
                    backgroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF0E0E0E),
                    foregroundColor: isDark ? Colors.black : Colors.white,
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

  // ─── Duration Subtitle ────────────────────────────────────────────────────

  String _getDurationSubtitle() {
    switch (_duration) {
      case PostDuration.h24:
        return 'Disappears after one day';
      case PostDuration.h36:
        return 'Extended temporary visibility';
      case PostDuration.lifetime:
        return 'Stays on your profile permanently';
    }
  }

  // ─── Premium Segmented Duration Toggle ────────────────────────────────────

  Widget _buildDurationToggle(bool isDark) {
    final segments = [
      {'label': '24h', 'icon': Icons.timelapse_rounded},
      {'label': '36h', 'icon': Icons.update_rounded},
      {'label': '∞', 'icon': Icons.all_inclusive_rounded},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 6) / 3; // 6 = padding

        return Container(
          height: 52,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              // ── Sliding active pill ──
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: _durationIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Tap targets ──
              Row(
                children: List.generate(3, (i) {
                  final isActive = _durationIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        KnockHaptics.tap();
                        setState(() {
                          switch (i) {
                            case 0:
                              _duration = PostDuration.h24;
                              break;
                            case 1:
                              _duration = PostDuration.h36;
                              break;
                            case 2:
                              _duration = PostDuration.lifetime;
                              break;
                          }
                        });
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isActive
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.black.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  segments[i]['icon'] as IconData,
                                  key: ValueKey('$i-$isActive'),
                                  size: 16,
                                  color: isActive
                                      ? (isDark ? Colors.black : Colors.white)
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.4,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.35,
                                              )),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(segments[i]['label'] as String),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Audience Card (Monochrome Knockpost style) ──────────────────────────

  Widget _buildAudienceOption(PostAudience aud, bool isDark) {
    final isSelected = _audience == aud;

    return GestureDetector(
      onTap: () async {
        KnockHaptics.tap();
        if (aud == PostAudience.myFriendsExcept) {
          final result = await showFriendPickerScreen(
            context,
            title: aud.label,
            subtitle: aud.subtitle,
            accentColor: isDark ? Colors.white : Colors.black,
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
            accentColor: isDark ? Colors.white : Colors.black,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Icon circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                aud.icon,
                size: 18,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aud.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
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
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
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
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.18)),
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
