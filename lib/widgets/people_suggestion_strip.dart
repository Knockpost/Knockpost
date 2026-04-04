import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/global_knock_state.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../utils/haptic_helper.dart';
import '../screens/profile/widgets/knock_button.dart';
import '../screens/profile/other_profile_screen.dart';
import '../screens/discover/discover_people_screen.dart';

// ─── Demo suggested users ────────────────────────────────────────────────────

final List<UserModel> demoSuggestedUsers = [
  const UserModel(
    id: 'zayn01',
    displayName: 'Zayn Malik',
    username: 'zayn.malik',
    bio: 'Singer & songwriter 🎤 | Former 1D',
    avatarAsset: 'assets/test1.jpg',
    coverImageAsset: 'assets/test2.jpg',
    friendsCount: 52400,
    accountType: AccountType.creator,
    rank: CreatorRank.impact,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 24,
    mutualFriendsAvatars: ['assets/test2.jpg', 'assets/test3.jpg', 'assets/test4.jpg'],
    mutualFriendsWhoKnocked: ['assets/test2.jpg', 'assets/test3.jpg', 'assets/test4.jpg'],
  ),
  const UserModel(
    id: 'justin01',
    displayName: 'Justin Bieber',
    username: 'justin.bieber',
    avatarAsset: 'assets/test2.jpg',
    friendsCount: 84200,
    accountType: AccountType.creator,
    rank: CreatorRank.plus,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 15,
    mutualFriendsAvatars: ['assets/test1.jpg', 'assets/test4.jpg'],
    mutualFriendsWhoKnocked: ['assets/test1.jpg', 'assets/test4.jpg'],
  ),
  const UserModel(
    id: 'suman01',
    displayName: 'Suman Patra',
    username: 'suman.patra',
    bio: 'Keep it private 🔒',
    avatarAsset: 'assets/test3.jpg',
    coverImageAsset: 'assets/test4.jpg',
    friendsCount: 142,
    accountType: AccountType.normal,
    privacyType: PrivacyType.private,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 3,
    mutualFriendsAvatars: ['assets/test1.jpg', 'assets/test3.jpg'],
    mutualFriendsWhoKnocked: ['assets/test1.jpg', 'assets/test3.jpg'],
  ),
  const UserModel(
    id: 'saptarshi01',
    displayName: 'Saptarshi Nayak',
    username: 'saptarshi.nayak',
    bio: 'Open book 📖 | Exploring life',
    avatarAsset: 'assets/test4.jpg',
    coverImageAsset: 'assets/test1.jpg',
    friendsCount: 890,
    accountType: AccountType.normal,
    privacyType: PrivacyType.open,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 8,
    mutualFriendsAvatars: ['assets/test2.jpg', 'assets/test3.jpg'],
  ),
  const UserModel(
    id: 'arya01',
    displayName: 'Arya Layek',
    username: 'arya.layek',
    bio: 'Creator & storyteller ✨ | Pro vibes',
    avatarAsset: 'assets/test1.jpg',
    coverImageAsset: 'assets/test3.jpg',
    friendsCount: 15400,
    accountType: AccountType.creator,
    rank: CreatorRank.pro,
    knockStatus: KnockStatus.theyKnockedYou,
    mutualFriendsCount: 31,
    mutualFriendsAvatars: ['assets/test2.jpg', 'assets/test3.jpg', 'assets/test4.jpg'],
    mutualFriendsWhoKnocked: ['assets/test2.jpg', 'assets/test3.jpg', 'assets/test4.jpg'],
  ),
  const UserModel(
    id: 'leo01',
    displayName: 'Leonardo DiCaprio',
    username: 'leo.dicaprio',
    bio: 'Actor & environmentalist 🌍',
    avatarAsset: 'assets/test2.jpg',
    coverImageAsset: 'assets/test4.jpg',
    friendsCount: 320,
    accountType: AccountType.normal,
    privacyType: PrivacyType.open,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 5,
    mutualFriendsAvatars: ['assets/test1.jpg', 'assets/test4.jpg'],
  ),
];



// ─── Widget ──────────────────────────────────────────────────────────────────

class PeopleSuggestionStrip extends StatefulWidget {
  const PeopleSuggestionStrip({super.key});

  @override
  State<PeopleSuggestionStrip> createState() => _PeopleSuggestionStripState();
}

class _PeopleSuggestionStripState extends State<PeopleSuggestionStrip> {
  late List<UserModel> _users;
  late final Map<String, KnockStatus> _statuses;
  final Map<String, GlobalKey<_AnimatedDismissCardState>> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _users = List.of(demoSuggestedUsers);
    _statuses = {
      for (final u in _users) u.id: u.knockStatus,
    };
    for (final u in _users) {
      _cardKeys[u.id] = GlobalKey<_AnimatedDismissCardState>();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_users.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Text(
                'People you may know',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  KnockHaptics.tap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DiscoverPeopleScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal scroll ────────────────────────────────────────────────
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              final cardKey = _cardKeys[user.id]!;
              return _AnimatedDismissCard(
                key: cardKey,
                child: Padding(
                  padding: EdgeInsets.only(right: index < _users.length - 1 ? 10 : 0),
                  child: _SuggestionCard(
                    user: user,
                    knockStatus: _statuses[user.id]!,
                    onKnockChanged: (status) {
                      setState(() => _statuses[user.id] = status);
                    },
                    onDismiss: () {
                      cardKey.currentState?.dismiss(() {
                        if (mounted) {
                          setState(() {
                            _users.remove(user);
                          });
                        }
                      });
                    },
                    onRemove: () {
                      cardKey.currentState?.dismiss(() {
                        if (mounted) {
                          setState(() {
                            _users.remove(user);
                          });
                        }
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Animated Dismiss Wrapper ────────────────────────────────────────────────

class _AnimatedDismissCard extends StatefulWidget {
  final Widget child;

  const _AnimatedDismissCard({super.key, required this.child});

  @override
  State<_AnimatedDismissCard> createState() => _AnimatedDismissCardState();
}

class _AnimatedDismissCardState extends State<_AnimatedDismissCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shrinkAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shrinkAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInCubic),
    );
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Trigger dismiss animation, then call [onComplete] to remove from list.
  void dismiss(VoidCallback onComplete) {
    _ctrl.forward().then((_) {
      if (mounted) onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      axis: Axis.horizontal,
      sizeFactor: _shrinkAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: widget.child,
      ),
    );
  }
}

// ─── Single card ─────────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final UserModel user;
  final KnockStatus knockStatus;
  final ValueChanged<KnockStatus> onKnockChanged;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  const _SuggestionCard({
    required this.user,
    required this.knockStatus,
    required this.onKnockChanged,
    required this.onRemove,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2);

    return Container(
      width: 136,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              // Main content (Profile Info)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: user.avatarAsset != null
                          ? (user.avatarAsset!.startsWith('assets/')
                              ? AssetImage(user.avatarAsset!) as ImageProvider
                              : FileImage(File(user.avatarAsset!)))
                          : null,
                      backgroundColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFE8E8E8),
                      child: user.avatarAsset == null
                          ? Icon(Icons.person,
                              size: 30,
                              color: isDark ? Colors.white54 : Colors.black38)
                          : null,
                    ),

                    const SizedBox(height: 10),

                    // Display Name
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),

                    const SizedBox(height: 2),

                    // Username or bio snippet
                    Text(
                      user.bio ?? '@${user.username}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white38 : Colors.black45,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Mutual friends section
                    SizedBox(
                      height: 20,
                      child: user.mutualFriendsCount > 0
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (user.mutualFriendsAvatars.isNotEmpty)
                                  _MutualFriendsOverlap(
                                    avatars: user.mutualFriendsAvatars,
                                  ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    user.mutualFriendsCount > 1
                                        ? 'Mutuals'
                                        : 'Mutual',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              const Spacer(),
              
              Divider(
                height: 1, 
                thickness: 0.5,
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              ),

              // Bottom Action Button (Text-only)
              _SuggestionAction(
                userId: user.id,
                status: knockStatus,
                privacyType: user.privacyType,
                onChanged: onKnockChanged,
                onDismiss: onDismiss,
              ),
            ],
          ),
          
          // Transparent link to profile on upper body
          Positioned.fill(
            bottom: 40,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtherProfileScreen(
                      user: user.copyWith(knockStatus: knockStatus),
                      posts: getDemoPostsForUser(user.id),
                      onKnockStatusChanged: onKnockChanged,
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),
          // Close button (X)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Text Action Button (Bottom of card) ─────────────────────────────────────

class _SuggestionAction extends StatefulWidget {
  final String userId;
  final KnockStatus status;
  final PrivacyType privacyType;
  final ValueChanged<KnockStatus> onChanged;
  final VoidCallback onDismiss;

  const _SuggestionAction({
    required this.userId,
    required this.status,
    required this.privacyType,
    required this.onChanged,
    required this.onDismiss,
  });

  @override
  State<_SuggestionAction> createState() => _SuggestionActionState();
}

class _SuggestionActionState extends State<_SuggestionAction>
    with SingleTickerProviderStateMixin {
  late ValueNotifier<KnockStatus> _globalNotifier;
  late KnockStatus _status;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _globalNotifier = GlobalKnockState.getNotifier(widget.userId, widget.status);
    _status = _globalNotifier.value;
    _globalNotifier.addListener(_onGlobalChange);
    
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  void _onGlobalChange() {
    if (mounted && _status != _globalNotifier.value) {
      setState(() => _status = _globalNotifier.value);
    }
  }

  @override
  void didUpdateWidget(covariant _SuggestionAction old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _globalNotifier.removeListener(_onGlobalChange);
      _globalNotifier = GlobalKnockState.getNotifier(widget.userId, widget.status);
      _status = _globalNotifier.value;
      _globalNotifier.addListener(_onGlobalChange);
    }
  }

  @override
  void dispose() {
    _globalNotifier.removeListener(_onGlobalChange);
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    _ctrl.reverse().then((_) => _ctrl.forward());
    KnockHaptics.impact();
    final KnockStatus newStatus;
    switch (_status) {
      case KnockStatus.none:
        newStatus = widget.privacyType == PrivacyType.open
            ? KnockStatus.knocked
            : KnockStatus.pending;
        break;
      case KnockStatus.theyKnockedYou:
        newStatus = KnockStatus.mutualKnocked;
        break;
      default:
        newStatus = KnockStatus.none;
    }
    setState(() => _status = newStatus);
    _globalNotifier.value = newStatus;
    
    widget.onChanged(newStatus);
    // If knocked, dismiss the card after a brief delay
    if (newStatus == KnockStatus.knocked ||
        newStatus == KnockStatus.pending ||
        newStatus == KnockStatus.mutualKnocked) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKnocked = _status == KnockStatus.knocked ||
        _status == KnockStatus.pending ||
        _status == KnockStatus.mutualKnocked;

    final label = switch (_status) {
      KnockStatus.none => 'Knock',
      KnockStatus.pending => 'Knocked',
      KnockStatus.knocked => 'Knocked',
      KnockStatus.mutualKnocked => 'Knocked',
      KnockStatus.theyKnockedYou => 'Knock Back',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _tap,
        child: Container(
          height: 38,
          width: double.infinity,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isKnocked
                  ? (isDark ? Colors.white38 : Colors.black26)
                  : (isDark ? Colors.white : Colors.black),
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Overlapping Avatars Widget ──────────────────────────────────────────────

class _MutualFriendsOverlap extends StatelessWidget {
  final List<String> avatars;

  const _MutualFriendsOverlap({required this.avatars});

  @override
  Widget build(BuildContext context) {
    // Only show up to 3 avatars
    final displayAvatars = avatars.take(3).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 18,
      width: 18.0 + (displayAvatars.length - 1) * 10,
      child: Stack(
        children: List.generate(displayAvatars.length, (index) {
          return Positioned(
            left: index * 10.0,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 8,
                backgroundImage: AssetImage(displayAvatars[index]),
                backgroundColor: Colors.grey[300],
              ),
            ),
          );
        }),
      ),
    );
  }
}

