import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/profile/widgets/knock_button.dart';
import '../screens/profile/profile_screen.dart';

// ─── Demo suggested users ────────────────────────────────────────────────────

final List<UserModel> demoSuggestedUsers = [
  const UserModel(
    id: 'sug01',
    displayName: 'Ananya Sen',
    username: 'ananya.sen',
    bio: 'Art & design enthusiast 🎨',
    avatarAsset: 'assets/test4.jpg',
    friendsCount: 320,
    accountType: AccountType.normal,
    privacyType: PrivacyType.open,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 12,
    mutualFriendsAvatars: ['assets/test1.jpg', 'assets/test2.jpg', 'assets/test3.jpg'],
  ),
  const UserModel(
    id: 'sug02',
    displayName: 'Rohan Das',
    username: 'rohan.das',
    bio: 'Coder by day 💻 Gamer by night 🎮',
    avatarAsset: 'assets/test3.jpg',
    friendsCount: 512,
    accountType: AccountType.normal,
    privacyType: PrivacyType.open,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 5,
    mutualFriendsAvatars: ['assets/test4.jpg', 'assets/test1.jpg'],
  ),
  const UserModel(
    id: 'sug03',
    displayName: 'Priya Ghosh',
    username: 'priya.g',
    bio: 'Travel | Food | Life 🌍',
    avatarAsset: 'assets/test2.jpg',
    friendsCount: 145,
    accountType: AccountType.creator,
    rank: CreatorRank.echo,
    knockStatus: KnockStatus.theyKnockedYou,
    mutualFriendsCount: 0,
    mutualFriendsAvatars: [],
  ),
  const UserModel(
    id: 'sug04',
    displayName: 'Arjit Bose',
    username: 'arjit.b',
    bio: 'Music producer 🎹',
    avatarAsset: 'assets/test1.jpg',
    friendsCount: 2100,
    accountType: AccountType.creator,
    rank: CreatorRank.plus,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 31,
    mutualFriendsAvatars: ['assets/test2.jpg', 'assets/test3.jpg', 'assets/test4.jpg'],
  ),
  const UserModel(
    id: 'sug05',
    displayName: 'Mehak Jain',
    username: 'mehak.j',
    bio: 'Fashion & lifestyle ✨',
    avatarAsset: 'assets/test4.jpg',
    friendsCount: 890,
    accountType: AccountType.normal,
    privacyType: PrivacyType.private,
    knockStatus: KnockStatus.none,
    mutualFriendsCount: 8,
    mutualFriendsAvatars: ['assets/test1.jpg', 'assets/test3.jpg'],
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

  @override
  void initState() {
    super.initState();
    _users = List.of(demoSuggestedUsers);
    _statuses = {
      for (final u in _users) u.id: u.knockStatus,
    };
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal scroll ────────────────────────────────────────────────
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final user = _users[index];
              return _SuggestionCard(
                user: user,
                knockStatus: _statuses[user.id]!,
                onKnockChanged: (status) {
                  setState(() => _statuses[user.id] = status);
                },
                onRemove: () {
                  setState(() {
                    _users.remove(user);
                  });
                },
              );
            },
          ),
        ),

        // ── Bottom divider ───────────────────────────────────────────────────
        const SizedBox(height: 8),
        Divider(
          thickness: 6,
          height: 6,
          color: isDark ? const Color(0xff121212) : const Color(0xfff0f0f0),
        ),
      ],
    );
  }
}

// ─── Single card ─────────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final UserModel user;
  final KnockStatus knockStatus;
  final ValueChanged<KnockStatus> onKnockChanged;
  final VoidCallback onRemove;

  const _SuggestionCard({
    required this.user,
    required this.knockStatus,
    required this.onKnockChanged,
    required this.onRemove,
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
                          ? AssetImage(user.avatarAsset!)
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
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),

              // Bottom Action Button (Text-only)
              _SuggestionAction(
                status: knockStatus,
                privacyType: user.privacyType,
                onChanged: onKnockChanged,
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
                    builder: (_) => ProfileScreen(
                      user: user,
                      posts: const [],
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
  final KnockStatus status;
  final PrivacyType privacyType;
  final ValueChanged<KnockStatus> onChanged;

  const _SuggestionAction({
    required this.status,
    required this.privacyType,
    required this.onChanged,
  });

  @override
  State<_SuggestionAction> createState() => _SuggestionActionState();
}

class _SuggestionActionState extends State<_SuggestionAction>
    with SingleTickerProviderStateMixin {
  late KnockStatus _status;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant _SuggestionAction old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _status = widget.status;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    _ctrl.reverse().then((_) => _ctrl.forward());
    setState(() {
      switch (_status) {
        case KnockStatus.none:
          _status = widget.privacyType == PrivacyType.open
              ? KnockStatus.knocked
              : KnockStatus.pending;
          break;
        case KnockStatus.theyKnockedYou:
          _status = KnockStatus.mutualKnocked;
          break;
        default:
          _status = KnockStatus.none;
      }
    });
    widget.onChanged(_status);
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

