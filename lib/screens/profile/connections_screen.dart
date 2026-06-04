import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/global_knock_state.dart';
import '../../widgets/knockpost_avatar.dart';
import '../../services/connection_service.dart';
import '../../services/database_service.dart';
import 'other_profile_screen.dart';
import 'widgets/creator_rank_badge.dart';
import '../messages/chat_screen.dart';
import '../../widgets/system_nav_bar_fill.dart';

/// KnockPost-native connections screen with segmented toggle, card tiles,
/// and staggered entrance animations.
class ConnectionsScreen extends StatefulWidget {
  final int initialTab; // 0 = You Knocked, 1 = Knocked You

  const ConnectionsScreen({super.key, this.initialTab = 0});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with TickerProviderStateMixin {
  late int _activeSegment;
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Entrance animation
  late AnimationController _listAnimController;

  // Real-time stream data (loaded from Firestore)
  List<UserModel> _sentPendingReal = [];
  List<UserModel> _sentAcceptedReal = [];
  List<UserModel> _incomingPendingReal = [];
  List<UserModel> _incomingAcceptedReal = [];
  List<UserModel> _mutualReal = [];

  bool _isLoading = true;

  // Track which users have been dismissed from the lists
  final Set<String> _dismissedIds = {};
  final Map<String, VoidCallback> _knockListeners = {};

  @override
  void initState() {
    super.initState();
    _activeSegment = widget.initialTab;
    _pageController = PageController(initialPage: widget.initialTab);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.microtask(() => _listAnimController.forward());

    // Perform one-time fetch (Phase C3 Optimization)
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);

    final futures = await Future.wait([
      ConnectionService.instance.getSentPendingKnockUids(),
      ConnectionService.instance.getSentAcceptedKnockUids(),
      ConnectionService.instance.getIncomingPendingKnockUids(),
      ConnectionService.instance.getIncomingAcceptedKnockUids(),
      ConnectionService.instance.getMutualConnectionUids(),
    ]);

    // PARALLELIZE the category profile fetching
    final profileFutures = await Future.wait([
      _loadUsersFromUids(futures[0]),
      _loadUsersFromUids(futures[1]),
      _loadUsersFromUids(futures[2]),
      _loadUsersFromUids(futures[3]),
      _loadUsersFromUids(futures[4]),
    ]);

    if (mounted) {
      setState(() {
        _sentPendingReal = profileFutures[0];
        _sentAcceptedReal = profileFutures[1];
        _incomingPendingReal = profileFutures[2];
        _incomingAcceptedReal = profileFutures[3];
        _mutualReal = profileFutures[4];
        _isLoading = false;
      });
    }
  }

  Future<List<UserModel>> _loadUsersFromUids(List<String> uids) async {
    // PARALLELIZE the N user profile fetches
    final userFutures = uids.map((uid) async {
      final data = await DatabaseService.instance.getUserProfile(uid, useCache: true);
      if (data != null) return UserModel.fromMap(data, uid);
      return null;
    });
    
    final users = await Future.wait(userFutures);
    return users.whereType<UserModel>().toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listAnimController.dispose();
    _pageController.dispose();
    _knockListeners.clear();
    super.dispose();
  }

  List<UserModel> _filter(List<UserModel> users) {
    if (_searchQuery.isEmpty) return users.where((u) => !_dismissedIds.contains(u.id)).toList();
    return users.where((u) {
      if (_dismissedIds.contains(u.id)) return false;
      return u.username.toLowerCase().contains(_searchQuery) ||
          u.displayName.toLowerCase().contains(_searchQuery);
    }).toList();
  }


  // Combined: accepted knocks I sent + mutual connections who knocked me
  List<UserModel> get _youKnockedAccepted {
    final Set<String> seen = {};
    final List<UserModel> result = [];
    for (final u in _sentAcceptedReal) {
      if (seen.add(u.id)) result.add(u);
    }
    // Also include mutual connections who knocked me first (not already in sent list)
    for (final u in _mutualReal) {
      if (seen.add(u.id)) result.add(u);
    }
    return result;
  }

  List<UserModel> get _youKnockedPending {
    return _sentPendingReal;
  }

  // 'Knocked You' = everyone who knocked ME:
  //   - pending (not mutual yet) → show Knock Back
  //   - mutual (knocked back already) → show message

  int get _totalKnockedYou => _incomingPendingReal.length + _incomingAcceptedReal.length;

  int get _totalYouKnocked => _youKnockedAccepted.length;

  int get _totalConnections => _totalYouKnocked + _totalKnockedYou;

  /// Compact number: 999 → '999', 1200 → '1.2k', 52400 → '52.4k', 1000000 → '1m'
  static String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return v == v.roundToDouble() ? '${v.toInt()}m' : '${v.toStringAsFixed(1)}m';
    } else if (n >= 1000) {
      final v = n / 1000;
      return v == v.roundToDouble() ? '${v.toInt()}k' : '${v.toStringAsFixed(1)}k';
    }
    return n.toString();
  }

  void _onKnockBack(String userId) {
    KnockHaptics.impact();

        
    setState(() {
      final userIndex = _incomingAcceptedReal.indexWhere((u) => u.id == userId);
      if (userIndex != -1) {
        final user = _incomingAcceptedReal[userIndex];
        if (!_mutualReal.any((u) => u.id == userId)) {
          _mutualReal.add(user);
        }
      }
    });

    // Persist to Firestore
    ConnectionService.instance.acceptKnock(userId).catchError(
      (e) => debugPrint('ConnectionsScreen._onKnockBack error: $e'),
    );
  }

  void _onAcceptKnock(String userId) {
    KnockHaptics.impact();

        
    setState(() {
      final userIndex = _incomingPendingReal.indexWhere((u) => u.id == userId);
      if (userIndex != -1) {
        final user = _incomingPendingReal.removeAt(userIndex);
        _incomingAcceptedReal.add(user);
      }
    });

    // Persist to Firestore
    ConnectionService.instance.approveKnock(userId).catchError(
      (e) => debugPrint('ConnectionsScreen._onAcceptKnock error: $e'),
    );
  }

  Future<void> _onDismiss(String userId, String username) async {
    KnockHaptics.tap();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Decline Knock?',
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Are you sure you want to decline the knock from @$username?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.4),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _dismissedIds.add(userId);
      });
      // Update global state so that buttons elsewhere reset to 'Knock'
      GlobalKnockState.getNotifier(userId, KnockStatus.none).value = KnockStatus.none;
      await ConnectionService.instance.declineKnock(userId);
    }
  }

  void _onMessage(UserModel user) {
    KnockHaptics.tap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUser: user,
        ),
      ),
    );
  }

  void _switchSegment(int index) {
    if (index == _activeSegment) return;
    KnockHaptics.tap();
    setState(() => _activeSegment = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    // Re-run entrance anim for new tab
    _listAnimController.reset();
    _listAnimController.forward();
  }

  void _onPageChanged(int index) {
    if (index == _activeSegment) return;
    setState(() => _activeSegment = index);
    _listAnimController.reset();
    _listAnimController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bg,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_rounded,
                              color: textColor, size: 24),
                          splashRadius: 22,
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connections',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              '(${_formatCount(_totalConnections)}) people',
                              style: TextStyle(
                                color: subColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ── Tab toggle with sliding pill ──
                  _KnockPostPillToggle(
                    labels: [
                      'You Knocked (${_formatCount(_totalYouKnocked)})',
                      'Knocked You (${_formatCount(_totalKnockedYou)})',
                    ],
                    activeIndex: _activeSegment,
                    onChanged: _switchSegment,
                    isDark: isDark,
                    textColor: textColor,
                  ),

                  const SizedBox(height: 10),

                  // ── Search bar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SearchField(
                      controller: _searchController,
                      searchQuery: _searchQuery,
                      isDark: isDark,
                      textColor: textColor,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ── Swipeable list content ──
                  Expanded(
                    child: _isLoading 
                        ? Center(
                            child: CircularProgressIndicator(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          )
                        : PageView(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            children: [
                              RefreshIndicator(
                                onRefresh: _loadData,
                                color: isDark ? Colors.white : Colors.black,
                                backgroundColor: bg,
                                child: _buildYouKnockedList(isDark, textColor),
                              ),
                              RefreshIndicator(
                                onRefresh: _loadData,
                                color: isDark ? Colors.white : Colors.black,
                                backgroundColor: bg,
                                child: _buildKnockedYouList(isDark, textColor),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }

  // ── You Knocked tab ──
  Widget _buildYouKnockedList(bool isDark, Color textColor) {
    // Show everyone I knocked + mutual connections
    final accepted = _filter(_youKnockedAccepted);
    final pending = _filter(_youKnockedPending);
    
    final allEntries = [
      ...pending.map((u) => _KnockedYouEntry(u, _CardAction.pending)),
      ...accepted.map((u) => _KnockedYouEntry(u, _CardAction.message)),
    ];

    if (allEntries.isEmpty) {
      return _buildEmptyState(
        isDark,
        '👋',
        'No connections yet',
        'Start knocking to connect with people',
      );
    }

    return _StaggeredCardList(
      key: const ValueKey('you_knocked'),
      animController: _listAnimController,
      itemCount: allEntries.length,
      itemBuilder: (context, index) {
        final entry = allEntries[index];
        return _ConnectionCard(
          user: entry.user,
          isDark: isDark,
          textColor: textColor,
          actionType: entry.action,
          onProfileTap: () => _navigateToProfile(entry.user),
          onMessage: () => _onMessage(entry.user),
        );
      },
    );
  }

  // ── Knocked You tab ──
  Widget _buildKnockedYouList(bool isDark, Color textColor) {
    final mutualIds = _mutualReal.map((u) => u.id).toSet();
    final sentIds   = _sentAcceptedReal.map((u) => u.id).toSet();

    // 1. pending = knocked me but I haven't accepted or knocked back
    final pending = _filter(_incomingPendingReal)
        .where((u) => !mutualIds.contains(u.id) && !sentIds.contains(u.id))
        .toList();

    // 2. accepted not mutual = knocked me, I accepted (or I am open), but I haven't knocked back
    final acceptedNotMutual = _filter(_incomingAcceptedReal)
        .where((u) => !mutualIds.contains(u.id) && !sentIds.contains(u.id))
        .toList();

    // 3. mutual = knocked me AND I knocked back
    final mutual = _filter(_incomingAcceptedReal)
        .where((u) => mutualIds.contains(u.id) || sentIds.contains(u.id))
        .toList();

    final allEntries = [
      ...pending.map((u) => _KnockedYouEntry(u, _CardAction.accept)),
      ...acceptedNotMutual.map((u) => _KnockedYouEntry(u, _CardAction.knockBack)),
      ...mutual.map((u) => _KnockedYouEntry(u, _CardAction.message)),
    ];

    if (allEntries.isEmpty) {
      return _buildEmptyState(
        isDark,
        '🚪',
        'No pending knocks',
        'When someone knocks, they\'ll appear here',
      );
    }

    return _StaggeredCardList(
      key: const ValueKey('knocked_you'),
      animController: _listAnimController,
      itemCount: allEntries.length,
      itemBuilder: (context, index) {
        final entry = allEntries[index];
        return _ConnectionCard(
          user: entry.user,
          isDark: isDark,
          textColor: textColor,
          actionType: entry.action,
          onProfileTap: () => _navigateToProfile(entry.user),
          onKnockBack: () => _onKnockBack(entry.user.id),
          onAcceptKnock: () => _onAcceptKnock(entry.user.id),
          onDismiss: () => _onDismiss(entry.user.id, entry.user.username),
          onMessage: () => _onMessage(entry.user),
        );
      },
    );
  }

  Widget _buildEmptyState(
      bool isDark, String emoji, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(UserModel user) {
    KnockHaptics.tap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherProfileScreen(
          user: user,
          posts: const [],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KNOCKPOST-STYLE PILL TOGGLE — matches ProfileAnimatedTabBar
// ═══════════════════════════════════════════════════════════════════════════════

class _KnockPostPillToggle extends StatelessWidget {
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final bool isDark;
  final Color textColor;

  const _KnockPostPillToggle({
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;
    final divColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final pillColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                // ── Sliding pill ──
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubicEmphasized,
                  left: activeIndex * tabWidth + 6,
                  top: 0,
                  width: tabWidth - 12,
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // ── Labels ──
                Row(
                  children: List.generate(labels.length, (i) {
                    final isActive = i == activeIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(i),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeInOutCubic,
                              style: TextStyle(
                                fontSize: isActive ? 14.5 : 13.5,
                                fontWeight:
                                    isActive ? FontWeight.w800 : FontWeight.w500,
                                color: isActive ? textColor : inactiveColor,
                                letterSpacing: isActive ? -0.4 : 0,
                              ),
                              child: Text(labels[i]),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH FIELD
// ═══════════════════════════════════════════════════════════════════════════════

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final bool isDark;
  final Color textColor;

  const _SearchField({
    required this.controller,
    required this.searchQuery,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5);
    final hintColor = isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3);
    final borderColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search connections...',
          hintStyle: TextStyle(color: hintColor, fontSize: 14.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.search_rounded, color: hintColor, size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () => controller.clear(),
                  icon: Icon(Icons.close_rounded, color: hintColor, size: 18),
                  splashRadius: 16,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGGERED CARD LIST  –  fade + slide from bottom
// ═══════════════════════════════════════════════════════════════════════════════

class _StaggeredCardList extends StatelessWidget {
  final AnimationController animController;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const _StaggeredCardList({
    super.key,
    required this.animController,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Stagger: each card starts a bit later
        final start = (index * 0.08).clamp(0.0, 0.6);
        final end = (start + 0.4).clamp(0.0, 1.0);

        final slideAnim = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ));

        final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );

        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: slideAnim,
            child: itemBuilder(context, index),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONNECTION CARD TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _KnockedYouEntry {
  final UserModel user;
  final _CardAction action;
  const _KnockedYouEntry(this.user, this.action);
}

enum _CardAction { message, knockBack, knocked, pending, accept }

class _ConnectionCard extends StatefulWidget {
  final UserModel user;
  final bool isDark;
  final Color textColor;
  final _CardAction actionType;
  final VoidCallback onProfileTap;
  final VoidCallback? onKnockBack;
  final VoidCallback? onAcceptKnock;
  final VoidCallback? onDismiss;
  final VoidCallback? onMessage;

  const _ConnectionCard({
    required this.user,
    required this.isDark,
    required this.textColor,
    required this.actionType,
    required this.onProfileTap,
    this.onKnockBack,
    this.onAcceptKnock,
    this.onDismiss,
    this.onMessage,
  });

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final user = widget.user;
    final textColor = widget.textColor;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return InkWell(
      onTap: widget.onProfileTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // ── Avatar ──
            _buildAvatar(user, isDark),

            const SizedBox(width: 14),

            // ── Username (primary) + display name (secondary) ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.username,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.accountType == AccountType.creator) ...[
                        const SizedBox(width: 6),
                        CreatorRankBadge(rank: user.rank, mini: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.displayName,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ── Action area ──
            if (widget.actionType == _CardAction.message)
              _buildMessageAction(isDark, textColor)
            else if (widget.actionType == _CardAction.knocked)
              _buildKnockedAction(isDark, textColor)
            else if (widget.actionType == _CardAction.pending)
              _buildPendingAction(isDark, textColor)
            else if (widget.actionType == _CardAction.accept)
              _buildAcceptAction(isDark, textColor)
            else
              _buildKnockBackAction(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel user, bool isDark) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: KnockPostAvatar(
        url: user.avatarAsset,
        radius: 25,
        name: user.displayName,
      ),
    );
  }

  Widget _buildMessageAction(bool isDark, Color textColor) {
    return GestureDetector(
      onTap: widget.onMessage,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          size: 18,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildKnockBackAction(bool isDark, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Knock back button — solid fill, matching KnockPost style
        GestureDetector(
          onTap: widget.onKnockBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Knock back',
              style: TextStyle(
                color: isDark ? Colors.black : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Dismiss
        GestureDetector(
          onTap: widget.onDismiss,
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptAction(bool isDark, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onAcceptKnock,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Accept',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: widget.onDismiss,
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildKnockedAction(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Knocked',
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black54,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPendingAction(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black26,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Pending',
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black54,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

