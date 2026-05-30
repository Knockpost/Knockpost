import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../utils/global_knock_state.dart';
import '../utils/global_dismiss_state.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../utils/haptic_helper.dart';
import '../screens/profile/widgets/knock_button.dart';
import '../screens/discover/discover_people_screen.dart';
import '../screens/profile/other_profile_screen.dart';
import '../services/post_service.dart';
import '../services/database_service.dart';
import '../services/current_user_service.dart';
import '../services/connection_service.dart';
import 'knockpost_avatar.dart';

// ─── Demo suggested users ────────────────────────────────────────────────────





// ─── Widget ──────────────────────────────────────────────────────────────────

class PeopleSuggestionStrip extends StatefulWidget {
  const PeopleSuggestionStrip({super.key});

  @override
  State<PeopleSuggestionStrip> createState() => _PeopleSuggestionStripState();
}

class _PeopleSuggestionStripState extends State<PeopleSuggestionStrip> {
  List<UserModel> _users = [];
  Map<String, KnockStatus> _statuses = {};
  final Map<String, GlobalKey<_AnimatedDismissCardState>> _cardKeys = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    // Listen for global dismissals (e.g., from profile screen)
    GlobalDismissState.dismissedUserIds.addListener(_onGlobalDismissalChanged);
  }

  Future<void> _fetchUsers() async {
    final currentUserId = CurrentUserService.instance.currentUser?.id;
    final fetchedUsers = await DatabaseService.instance.getSuggestedUsers(
      excludeUid: currentUserId,
      limitCount: 30, // Fetch more to ensure we have enough after filtering
    );
    
    if (!mounted) return;

    final statuses = await Future.wait(fetchedUsers.map((u) async {
      var status = GlobalKnockState.getNotifier(u.id, u.knockStatus).value;
      if (status == KnockStatus.none) {
        status = await ConnectionService.instance.getKnockStatus(u.id);
        GlobalKnockState.getNotifier(u.id, status).value = status;
      }
      return status;
    }));

    final validUsers = <UserModel>[];
    final validStatuses = <String, KnockStatus>{};

    for (int i = 0; i < fetchedUsers.length; i++) {
      final u = fetchedUsers[i];
      if (GlobalDismissState.isDismissed(u.id)) continue;
      
      final status = statuses[i];
      if (status != KnockStatus.knocked &&
          status != KnockStatus.pending &&
          status != KnockStatus.mutualKnocked) {
        validUsers.add(u);
        validStatuses[u.id] = status;
      }
    }

    if (mounted) {
      setState(() {
        _users = validUsers.take(15).toList(); // Limit to 15 for the strip
        _statuses = validStatuses;
        for (final u in _users) {
          _cardKeys[u.id] = GlobalKey<_AnimatedDismissCardState>();
        }
        _isLoading = false;
      });
    }
  }

  void _onGlobalDismissalChanged() {
    final dismissed = GlobalDismissState.dismissedUserIds.value;
    for (final userId in dismissed) {
      if (_users.any((u) => u.id == userId)) {
        final cardKey = _cardKeys[userId];
        if (cardKey?.currentState != null) {
          cardKey!.currentState!.dismiss(() {
            if (mounted) {
              setState(() {
                _users.removeWhere((u) => u.id == userId);
              });
            }
          });
        } else if (mounted) {
          // If not currently in building state or off-screen, just remove
          setState(() {
            _users.removeWhere((u) => u.id == userId);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    GlobalDismissState.dismissedUserIds.removeListener(_onGlobalDismissalChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: KnockpostLoadingIndicator()),
      );
    }
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
              Icon(
                Icons.person_add_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 6),
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
                    MaterialPageRoute(builder: (_) => const DiscoverPeopleScreen()),
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
                      // Already called GlobalDismissState.dismiss in _SuggestionAction
                    },
                    onRemove: () {
                      KnockHaptics.impact();
                      GlobalDismissState.dismiss(user.id);
                    },
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
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
                    KnockpostAvatar(
                      url: user.avatarAsset,
                      radius: 30,
                      name: user.displayName,
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
                                      fontWeight: FontWeight.w700,
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
                isEffectivelyOpen: user.isEffectivelyOpen,
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
                    builder: (_) => StreamBuilder<List<PostModel>>(
                      stream: PostService.instance.getUserPosts(user.id),
                      builder: (context, snapshot) {
                        return OtherProfileScreen(
                          user: user.copyWith(knockStatus: knockStatus),
                          posts: snapshot.data ?? [],
                          onKnockStatusChanged: onKnockChanged,
                        );
                      },
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
  final bool isEffectivelyOpen;
  final ValueChanged<KnockStatus> onChanged;
  final VoidCallback onDismiss;

  const _SuggestionAction({
    required this.userId,
    required this.status,
    required this.isEffectivelyOpen,
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
      case KnockStatus.theyKnockedYouPending:
        final isOpen = widget.isEffectivelyOpen;
        newStatus = isOpen ? KnockStatus.knocked : KnockStatus.pending;
        ConnectionService.instance.sendKnock(
          toUid: widget.userId,
          isOpenProfile: isOpen,
        );
        break;
      case KnockStatus.theyKnockedYou:
        newStatus = KnockStatus.mutualKnocked;
        ConnectionService.instance.acceptKnock(widget.userId);
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
        if (mounted) GlobalDismissState.dismiss(widget.userId);
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
      KnockStatus.theyKnockedYouPending => 'Knock',
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
              child: KnockpostAvatar(
                url: displayAvatars[index],
                radius: 8,
              ),
            ),
          );
        }),
      ),
    );
  }
}

