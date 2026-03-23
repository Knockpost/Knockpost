import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import 'widgets/creator_rank_badge.dart';
import 'widgets/profile_ui_helpers.dart';

/// Profile Settings screen — includes Professional mode toggle
class ProfileSettingsScreen extends StatefulWidget {
  final UserModel user;

  const ProfileSettingsScreen({super.key, required this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late UserModel _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _toggleProfessional(bool value) {
    KnockHaptics.impact();
    setState(() {
      _user = _user.copyWith(
        accountType: value ? AccountType.creator : AccountType.normal,
        rank: CreatorRank.echo,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor =
        isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
    final sectionBg =
        isDark ? const Color(0xFF111111) : const Color(0xFFF8F8F8);

    final isPro = _user.accountType == AccountType.creator;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: textColor),
            onPressed: () => Navigator.pop(context, _user),
          ),
          centerTitle: true,
          title: Text(
            'Settings',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Account section ────────────────────────────────────────────
            _SectionHeader('Account', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Switch to Professional',
                  subtitle: isPro
                      ? 'You are a Creator. Rank: ${_user.rankLabel}'
                      : 'Unlock Creator rank, visible to everyone.',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPro) ...[
                        CreatorRankBadge(rank: _user.rank, large: true),
                        const SizedBox(width: 8),
                      ],
                      Switch(
                        value: isPro,
                        onChanged: _toggleProfessional,
                        activeThumbColor: textColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isPro) ...[
              const SizedBox(height: 4),
              const RankInfoCard(),
            ],

            const SizedBox(height: 20),

            // ── Privacy section ────────────────────────────────────────────
            _SectionHeader('Privacy', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Blocked accounts',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.black38),
                  onTap: () {},
                ),
                ProfileSettingsRow(
                  title: 'Knock requests',
                  subtitle: 'Manage pending knocks',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.black38),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── About section ──────────────────────────────────────────────
            _SectionHeader('About', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                const ProfileSettingsRow(
                  title: 'KnockPost v1.0.0',
                ),
                ProfileSettingsRow(
                  title: 'Privacy Policy',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.black38),
                  onTap: () {},
                ),
                ProfileSettingsRow(
                  title: 'Terms of Service',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.black38),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Sign out ───────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  KnockHaptics.impact();
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.45)),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader(this.title, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Color bg;
  final Color divColor;
  final List<Widget> children;

  const _SettingsTile({
    required this.bg,
    required this.divColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divColor),
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: children.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: divColor, indent: 16, endIndent: 16),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: children[i],
        ),
      ),
    );
  }
}
