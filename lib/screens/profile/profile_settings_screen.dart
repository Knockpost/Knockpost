import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../theme/theme_controller.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/system_nav_bar_fill.dart';
import 'widgets/creator_rank_badge.dart';
import 'widgets/profile_ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_screen.dart';
import 'edit_profile_screen.dart';
import 'blocked_accounts_screen.dart';

/// Profile Settings screen — includes Professional mode toggle
class ProfileSettingsScreen extends StatefulWidget {
  final UserModel user;

  const ProfileSettingsScreen({super.key, required this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late UserModel _user;
  final String _accountEmail = 'arya.lk@gmail.com';

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
    final divColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);
    final sectionBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFF8F8F8);

    final isPro = _user.accountType == AccountType.creator;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            Navigator.pop(context, _user);
          }
        },
        child: Stack(
        children: [
          Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
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
            // ── Profile section ────────────────────────────────────────────
            _SectionHeader('Profile', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Edit Profile',
                  subtitle: 'Update your name, bio, and privacy options',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () async {
                    final updated = await Navigator.push<UserModel>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(user: _user),
                      ),
                    );
                    if (updated != null && mounted) {
                      setState(() => _user = updated);
                    }
                  },
                ),
                if (_user.accountType == AccountType.normal)
                  ProfileSettingsRow(
                    title: 'Private Account',
                    subtitle: 'Only accepted Knocks can see your profile & posts.',
                    trailing: Switch(
                      value: _user.privacyType == PrivacyType.private,
                      onChanged: (v) {
                        KnockHaptics.selection();
                        setState(() {
                          _user = _user.copyWith(
                            privacyType: v ? PrivacyType.private : PrivacyType.open,
                          );
                        });
                      },
                      activeThumbColor: textColor,
                    ),
                  ),
                if (isPro)
                  ProfileSettingsRow(
                    title: 'Professional stats',
                    subtitle: 'Views, likes, knocks and creator rank',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ProfessionalStatsScreen(user: _user),
                      ),
                    ),
                  ),
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

            if (isPro) ...[const SizedBox(height: 4), const RankInfoCard()],

            const SizedBox(height: 20),

            // ── Privacy section ────────────────────────────────────────────
            _SectionHeader('Preferences', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Display',
                  subtitle: 'Theme, text size and autoplay controls',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _DisplaySettingsScreen(),
                    ),
                  ),
                ),
                ProfileSettingsRow(
                  title: 'Time management',
                  subtitle: 'Daily limits, breaks and sleep mode',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _TimeManagementScreen(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── About section ──────────────────────────────────────────────
            _SectionHeader('Privacy', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Blocked accounts',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BlockedAccountsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            _SectionHeader('Account & Content', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Account',
                  subtitle: _accountEmail,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _AccountSettingsScreen(email: _accountEmail),
                    ),
                  ),
                ),
                ProfileSettingsRow(
                  title: 'Manage interests',
                  subtitle: 'Choose topics you want to see more often',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _ManageInterestsScreen(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _SectionHeader('About', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Feedback',
                  subtitle: 'Tell us what is working and what should improve',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _FeedbackScreen()),
                  ),
                ),
                const ProfileSettingsRow(title: 'KnockPost v1.0.0'),
                ProfileSettingsRow(
                  title: 'Privacy Policy',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () {},
                ),
                ProfileSettingsRow(
                  title: 'Terms of Service',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Sign out ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () async {
                  KnockHaptics.impact();
                  await FirebaseAuth.instance.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_registered', false);
                  
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.45),
                    ),
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
          SystemNavBarFill(color: bg),
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

class _DisplaySettingsScreen extends StatefulWidget {
  const _DisplaySettingsScreen();

  @override
  State<_DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<_DisplaySettingsScreen> {
  late ThemeMode _themeMode;
  bool _autoplayMedia = true;
  bool _largerText = false;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeController.themeMode.value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);
    final sectionBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFF8F8F8);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Display',
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
            _SectionHeader('Appearance', isDark: isDark),
            RadioGroup<ThemeMode>(
              groupValue: _themeMode,
              onChanged: (value) {
                if (value == null) return;
                KnockHaptics.selection();
                setState(() => _themeMode = value);
                ThemeController.updateThemeMode(value);
              },
              child: _SettingsTile(
                bg: sectionBg,
                divColor: divColor,
                children: [
                  ProfileSettingsRow(
                    title: 'Use device theme',
                    subtitle: 'Follow your phone theme settings',
                    trailing: Radio<ThemeMode>(
                      value: ThemeMode.system,
                      activeColor: textColor,
                    ),
                  ),
                  ProfileSettingsRow(
                    title: 'Light mode',
                    trailing: Radio<ThemeMode>(
                      value: ThemeMode.light,
                      activeColor: textColor,
                    ),
                  ),
                  ProfileSettingsRow(
                    title: 'Dark mode',
                    trailing: Radio<ThemeMode>(
                      value: ThemeMode.dark,
                      activeColor: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader('Reading', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Larger text',
                  subtitle: 'Increase text size for easier reading',
                  trailing: Switch(
                    value: _largerText,
                    onChanged: (value) {
                      KnockHaptics.selection();
                      setState(() => _largerText = value);
                    },
                    activeThumbColor: textColor,
                  ),
                ),
                ProfileSettingsRow(
                  title: 'Autoplay media previews',
                  subtitle: 'Play videos and animations automatically',
                  trailing: Switch(
                    value: _autoplayMedia,
                    onChanged: (value) {
                      KnockHaptics.selection();
                      setState(() => _autoplayMedia = value);
                    },
                    activeThumbColor: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }
}

class _AccountSettingsScreen extends StatelessWidget {
  final String email;

  const _AccountSettingsScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);
    final sectionBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFF8F8F8);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Account',
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
            _SectionHeader('Email', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Google account',
                  subtitle: email,
                  trailing: Icon(
                    Icons.mail_outline_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeader('Security', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Change password',
                  subtitle: 'Update your login password',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () {},
                ),
                ProfileSettingsRow(
                  title: 'Two-step verification',
                  subtitle: 'Add extra protection to your account',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }
}

class _ManageInterestsScreen extends StatefulWidget {
  const _ManageInterestsScreen();

  @override
  State<_ManageInterestsScreen> createState() => _ManageInterestsScreenState();
}

class _ManageInterestsScreenState extends State<_ManageInterestsScreen> {
  final Map<String, bool> _interests = {
    'Photography': true,
    'Travel': true,
    'Music': false,
    'Gaming': true,
    'Fashion': false,
    'Fitness': false,
    'Tech': true,
    'Food': true,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);
    final sectionBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFF8F8F8);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Manage Interests',
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
            _SectionHeader('Topics', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: _interests.entries
                  .map(
                    (entry) => ProfileSettingsRow(
                      title: entry.key,
                      subtitle: entry.value
                          ? 'Selected for your feed'
                          : 'Tap to add this interest',
                      trailing: Switch(
                        value: entry.value,
                        onChanged: (value) {
                          KnockHaptics.selection();
                          setState(() => _interests[entry.key] = value);
                        },
                        activeThumbColor: textColor,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }
}

class _TimeManagementScreen extends StatefulWidget {
  const _TimeManagementScreen();

  @override
  State<_TimeManagementScreen> createState() => _TimeManagementScreenState();
}

class _TimeManagementScreenState extends State<_TimeManagementScreen> {
  int _dailyLimitMinutes = 60;
  int _breakReminderMinutes = 20;
  bool _sleepModeEnabled = true;
  TimeOfDay _sleepStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _sleepEnd = const TimeOfDay(hour: 7, minute: 0);
  final Map<String, int> _weeklyUsageMinutes = const {
    'Mon': 48,
    'Tue': 65,
    'Wed': 72,
    'Thu': 58,
    'Fri': 94,
    'Sat': 110,
    'Sun': 86,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);
    final sectionBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFF8F8F8);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Time management',
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
            _SectionHeader('Time spent', isDark: isDark),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: divColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_averageUsageMinutes min / day',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Average time spent over the last 7 days',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _UsageBarChart(
                    weeklyUsageMinutes: _weeklyUsageMinutes,
                    barColor: textColor,
                    labelColor: isDark ? Colors.white54 : Colors.black45,
                    trackColor: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This week total: $_totalUsageMinutes min',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader('Usage reminders', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Daily time limit',
                  subtitle: 'Remind me after $_dailyLimitMinutes minutes',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () => _pickDailyLimit(context),
                ),
                ProfileSettingsRow(
                  title: 'Take break reminders',
                  subtitle:
                      'Show a reminder every $_breakReminderMinutes minutes',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () => _pickBreakReminder(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeader('Sleep mode', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Turn on sleep mode',
                  subtitle:
                      'Pause notifications and auto-reply during quiet hours',
                  trailing: Switch(
                    value: _sleepModeEnabled,
                    onChanged: (value) {
                      KnockHaptics.selection();
                      setState(() => _sleepModeEnabled = value);
                    },
                    activeThumbColor: textColor,
                  ),
                ),
                ProfileSettingsRow(
                  title: 'Start time',
                  subtitle: _formatTime(_sleepStart),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: _sleepModeEnabled
                      ? () => _pickTime(
                          context: context,
                          initialValue: _sleepStart,
                          onSelected: (value) =>
                              setState(() => _sleepStart = value),
                        )
                      : null,
                ),
                ProfileSettingsRow(
                  title: 'End time',
                  subtitle: _formatTime(_sleepEnd),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: _sleepModeEnabled
                      ? () => _pickTime(
                          context: context,
                          initialValue: _sleepEnd,
                          onSelected: (value) =>
                              setState(() => _sleepEnd = value),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }

  Future<void> _pickDailyLimit(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => _TimePickerSheet(
        title: 'Daily time limit',
        options: const [30, 45, 60, 90, 120, 180],
        selectedValue: _dailyLimitMinutes,
      ),
    );
    if (selected == null) return;
    KnockHaptics.selection();
    setState(() => _dailyLimitMinutes = selected);
  }

  Future<void> _pickBreakReminder(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => _TimePickerSheet(
        title: 'Take break reminders',
        options: const [10, 20, 30, 45, 60],
        selectedValue: _breakReminderMinutes,
      ),
    );
    if (selected == null) return;
    KnockHaptics.selection();
    setState(() => _breakReminderMinutes = selected);
  }

  Future<void> _pickTime({
    required BuildContext context,
    required TimeOfDay initialValue,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: initialValue,
    );
    if (selected == null) return;
    KnockHaptics.selection();
    onSelected(selected);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  int get _totalUsageMinutes =>
      _weeklyUsageMinutes.values.fold(0, (sum, value) => sum + value);

  int get _averageUsageMinutes =>
      (_totalUsageMinutes / _weeklyUsageMinutes.length).round();
}

class _TimePickerSheet extends StatelessWidget {
  final String title;
  final List<int> options;
  final int selectedValue;

  const _TimePickerSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return SafeArea(
      child: Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (value) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '$value minutes',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: value == selectedValue
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                trailing: value == selectedValue
                    ? Icon(Icons.check_rounded, color: textColor)
                    : Icon(Icons.chevron_right_rounded, color: subColor),
                onTap: () => Navigator.pop(context, value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBarChart extends StatelessWidget {
  final Map<String, int> weeklyUsageMinutes;
  final Color barColor;
  final Color labelColor;
  final Color trackColor;

  const _UsageBarChart({
    required this.weeklyUsageMinutes,
    required this.barColor,
    required this.labelColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxMinutes = weeklyUsageMinutes.values.reduce(
      (a, b) => a > b ? a : b,
    );

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weeklyUsageMinutes.entries.map((entry) {
          final ratio = maxMinutes == 0 ? 0.0 : entry.value / maxMinutes;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 22,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: ratio.clamp(0.08, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProfessionalStatsScreen extends StatelessWidget {
  final UserModel user;

  const _ProfessionalStatsScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);
    final sectionBg = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFF8F8F8);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Professional stats',
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
            _SectionHeader('Overview', isDark: isDark),
            _SettingsTile(
              bg: sectionBg,
              divColor: divColor,
              children: [
                ProfileSettingsRow(
                  title: 'Creator rank',
                  subtitle: user.rankLabel,
                  trailing: CreatorRankBadge(rank: user.rank, large: true),
                ),
                ProfileSettingsRow(
                  title: 'Total views',
                  subtitle: '${user.totalViews}',
                ),
                ProfileSettingsRow(
                  title: 'Total likes',
                  subtitle: '${user.totalLikes}',
                ),
                ProfileSettingsRow(
                  title: 'Knocks received',
                  subtitle: '${user.totalKnocksReceived}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeader('Performance', isDark: isDark),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: divColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last 7 days',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _UsageBarChart(
                    weeklyUsageMinutes: const {
                      'Mon': 120,
                      'Tue': 150,
                      'Wed': 132,
                      'Thu': 168,
                      'Fri': 194,
                      'Sat': 210,
                      'Sun': 176,
                    },
                    barColor: textColor,
                    labelColor: isDark ? Colors.white54 : Colors.black45,
                    trackColor: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }
}

class _FeedbackScreen extends StatefulWidget {
  const _FeedbackScreen();

  @override
  State<_FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<_FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_feedbackController.text.trim().isEmpty) return;
    KnockHaptics.impact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Feedback submitted')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final fieldBg = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF6F6F6);
    final borderColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Feedback',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submit,
              child: Text(
                'Send',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text(
              'Share your thoughts',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us what you like, what feels off, or what you want next.',
              style: TextStyle(color: subColor, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 8,
                style: TextStyle(fontSize: 14.5, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Write your feedback...',
                  hintStyle: TextStyle(
                    color: textColor.withValues(alpha: 0.35),
                    fontSize: 14.5,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }
}
