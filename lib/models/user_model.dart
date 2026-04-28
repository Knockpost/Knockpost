// KnockPost — User Model
// Covers both Normal (Open/Private) and Creator (Professional) account types.

enum AccountType { normal, creator }

enum PrivacyType { open, private }

/// Creator-only rank, computed from views + likes + total knocks received
enum CreatorRank { echo, plus, pro, impact }

/// Knock relationship state between the current viewer and this profile
enum KnockStatus {
  none, // No interaction yet
  pending, // Current user knocked, awaiting acceptance
  knocked, // Knock accepted (mutual / one-way accepted)
  theyKnockedYou, // They knocked the current user first
  mutualKnocked, // Both knocked and accepted
}

class UserModel {
  final String id;
  final String displayName;
  final String username;
  final String? bio;
  final String? avatarAsset; // null = show default avatar
  final String? coverImageAsset; // background cover image
  final int friendsCount;
  // Avatar assets of viewer's friends who knocked this profile.
  final List<String> mutualFriendsWhoKnocked;

  final AccountType accountType;
  final PrivacyType privacyType; // only meaningful for AccountType.normal

  // Creator-only
  final CreatorRank rank;
  final int totalViews;
  final int totalLikes;
  final int totalKnocksReceived;

  // Relationship with current viewer
  final KnockStatus knockStatus;

  final bool isOwnProfile;

  // Mutual connections count
  final int mutualFriendsCount;
  final List<String> mutualFriendsAvatars;
  final Map<String, String> socialLinks; // e.g. {'instagram': 'arjun.nayak', 'youtube': '...'}

  const UserModel({
    required this.id,
    required this.displayName,
    required this.username,
    this.bio,
    this.avatarAsset,
    this.coverImageAsset,
    this.friendsCount = 0,
    this.mutualFriendsWhoKnocked = const [],
    this.accountType = AccountType.normal,
    this.privacyType = PrivacyType.open,
    this.rank = CreatorRank.echo,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalKnocksReceived = 0,
    this.knockStatus = KnockStatus.none,
    this.isOwnProfile = false,
    this.mutualFriendsCount = 0,
    this.mutualFriendsAvatars = const [],
    this.socialLinks = const {},
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      displayName: map['displayName'] ?? map['fullName'] ?? '',
      username: map['username'] ?? '',
      bio: map['bio'],
      avatarAsset: map['profileImageUrl'] != null && map['profileImageUrl'].toString().isNotEmpty
          ? map['profileImageUrl']
          : null,
      coverImageAsset: map['coverImageUrl'],
      friendsCount: map['friendsCount'] ?? 0,
      mutualFriendsWhoKnocked: List<String>.from(map['mutualFriendsWhoKnocked'] ?? []),
      accountType: map['accountType'] == 'creator' ? AccountType.creator : AccountType.normal,
      privacyType: map['privacyType'] == 'private' ? PrivacyType.private : PrivacyType.open,
      rank: _parseRank(map['rank']),
      totalViews: map['totalViews'] ?? 0,
      totalLikes: map['totalLikes'] ?? 0,
      totalKnocksReceived: map['totalKnocksReceived'] ?? 0,
      knockStatus: _parseKnockStatus(map['knockStatus']),
      mutualFriendsCount: map['mutualFriendsCount'] ?? 0,
      socialLinks: Map<String, String>.from(map['socialLinks'] ?? {}),
    );
  }



  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'username': username,
      'bio': bio,
      'profileImageUrl': avatarAsset,
      'coverImageUrl': coverImageAsset,
      'friendsCount': friendsCount,
      'accountType': accountType.name,
      'privacyType': privacyType.name,
      'rank': rank.name,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalKnocksReceived': totalKnocksReceived,
      'mutualFriendsCount': mutualFriendsCount,
      'socialLinks': socialLinks,
    };
  }

  static CreatorRank _parseRank(String? rankStr) {
    if (rankStr == null) return CreatorRank.echo;
    switch (rankStr) {
      case 'plus': return CreatorRank.plus;
      case 'pro': return CreatorRank.pro;
      case 'impact': return CreatorRank.impact;
      default: return CreatorRank.echo;
    }
  }

  static KnockStatus _parseKnockStatus(String? statusStr) {
    if (statusStr == null) return KnockStatus.none;
    switch (statusStr) {
      case 'pending': return KnockStatus.pending;
      case 'knocked': return KnockStatus.knocked;
      case 'theyKnockedYou': return KnockStatus.theyKnockedYou;
      case 'mutualKnocked': return KnockStatus.mutualKnocked;
      default: return KnockStatus.none;
    }
  }

  /// Creator/professional profiles behave as open accounts.
  bool get isEffectivelyOpen =>
      accountType == AccountType.creator || privacyType == PrivacyType.open;

  /// Whether this profile's content is visible to the current viewer
  bool get isContentVisible {
    if (isOwnProfile) return true;
    if (isEffectivelyOpen) return true;
    // Private: only visible after knock accepted
    return knockStatus == KnockStatus.knocked ||
        knockStatus == KnockStatus.mutualKnocked;
  }

  /// Whether messaging is enabled (mutual accepted knock)
  bool get canMessage {
    if (isOwnProfile) return false;
    return knockStatus == KnockStatus.knocked ||
        knockStatus == KnockStatus.mutualKnocked;
  }

  /// Creator rank label string
  String get rankLabel {
    switch (rank) {
      case CreatorRank.echo:
        return 'ECHO';
      case CreatorRank.plus:
        return 'PLUS';
      case CreatorRank.pro:
        return 'PRO';
      case CreatorRank.impact:
        return 'IMPACT';
    }
  }

  UserModel copyWith({
    String? id,
    String? displayName,
    String? username,
    String? bio,
    String? avatarAsset,
    bool clearAvatar = false,
    String? coverImageAsset,
    bool clearCover = false,
    int? friendsCount,
    List<String>? mutualFriendsWhoKnocked,
    AccountType? accountType,
    PrivacyType? privacyType,
    CreatorRank? rank,
    int? totalViews,
    int? totalLikes,
    int? totalKnocksReceived,
    KnockStatus? knockStatus,
    bool? isOwnProfile,
    int? mutualFriendsCount,
    List<String>? mutualFriendsAvatars,
    Map<String, String>? socialLinks,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarAsset: clearAvatar ? null : (avatarAsset ?? this.avatarAsset),
      coverImageAsset: clearCover
          ? null
          : (coverImageAsset ?? this.coverImageAsset),
      friendsCount: friendsCount ?? this.friendsCount,
      mutualFriendsWhoKnocked:
          mutualFriendsWhoKnocked ?? this.mutualFriendsWhoKnocked,
      accountType: accountType ?? this.accountType,
      privacyType: privacyType ?? this.privacyType,
      rank: rank ?? this.rank,
      totalViews: totalViews ?? this.totalViews,
      totalLikes: totalLikes ?? this.totalLikes,
      totalKnocksReceived: totalKnocksReceived ?? this.totalKnocksReceived,
      knockStatus: knockStatus ?? this.knockStatus,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      mutualFriendsCount: mutualFriendsCount ?? this.mutualFriendsCount,
      mutualFriendsAvatars: mutualFriendsAvatars ?? this.mutualFriendsAvatars,
      socialLinks: socialLinks ?? this.socialLinks,
    );
  }
}

// ─── Demo data ───────────────────────────────────────────────────────────────

const demoOwnUser = UserModel(
  id: 'me',
  displayName: 'Arjun Nayak',
  username: 'arjun.nayak',
  bio: 'Building things 🛠 | Coffee addict ☕ | Kolkata',
  avatarAsset: 'assets/test1.jpg',
  coverImageAsset: 'assets/test2.jpg',
  friendsCount: 1200,
  accountType: AccountType.normal,
  privacyType: PrivacyType.open,
  isOwnProfile: true,
);

const demoZaynMalik = UserModel(
  id: 'zayn01',
  displayName: 'Zayn Malik',
  username: 'zayn.malik',
  bio: 'Singer & songwriter 🎤 | Former 1D | Night Thoughts',
  avatarAsset: 'assets/test1.jpg',
  coverImageAsset: 'assets/test2.jpg',
  friendsCount: 52400,
  mutualFriendsWhoKnocked: [
    'assets/test2.jpg',
    'assets/test3.jpg',
    'assets/test4.jpg',
  ],
  accountType: AccountType.creator,
  rank: CreatorRank.impact,
  totalViews: 520000,
  totalLikes: 98000,
  totalKnocksReceived: 12400,
);

const demoJustinBieber = UserModel(
  id: 'justin01',
  displayName: 'Justin Bieber',
  username: 'justin.bieber',
  avatarAsset: 'assets/test2.jpg',
  friendsCount: 84200,
  mutualFriendsWhoKnocked: ['assets/test1.jpg', 'assets/test4.jpg'],
  accountType: AccountType.creator,
  rank: CreatorRank.plus,
  totalViews: 340000,
  totalLikes: 72000,
  totalKnocksReceived: 8900,
);

const demoSumanPatra = UserModel(
  id: 'suman01',
  displayName: 'Suman Patra',
  username: 'suman.patra',
  bio: 'Keep it private 🔒',
  avatarAsset: 'assets/test3.jpg',
  coverImageAsset: 'assets/test4.jpg',
  friendsCount: 142,
  mutualFriendsWhoKnocked: ['assets/test1.jpg', 'assets/test3.jpg'],
  accountType: AccountType.normal,
  privacyType: PrivacyType.private,
  knockStatus: KnockStatus.none,
);

const demoSaptarshiNayak = UserModel(
  id: 'saptarshi01',
  displayName: 'Saptarshi Nayak',
  username: 'saptarshi.nayak',
  bio: 'Open book 📖 | Exploring life one day at a time',
  avatarAsset: 'assets/test4.jpg',
  coverImageAsset: 'assets/test1.jpg',
  friendsCount: 890,
  accountType: AccountType.normal,
  privacyType: PrivacyType.open,
  knockStatus: KnockStatus.knocked,
);

const demoAryaLayek = UserModel(
  id: 'arya01',
  displayName: 'Arya Layek',
  username: 'arya.layek',
  bio: 'Creator & storyteller ✨ | Pro vibes',
  avatarAsset: 'assets/test1.jpg',
  coverImageAsset: 'assets/test3.jpg',
  friendsCount: 15400,
  mutualFriendsWhoKnocked: [
    'assets/test2.jpg',
    'assets/test3.jpg',
    'assets/test4.jpg',
  ],
  accountType: AccountType.creator,
  rank: CreatorRank.pro,
  totalViews: 84000,
  totalLikes: 6200,
  totalKnocksReceived: 940,
);

const demoLeonardoDiCaprio = UserModel(
  id: 'leo01',
  displayName: 'Leonardo DiCaprio',
  username: 'leo.dicaprio',
  bio: 'Actor & environmentalist 🌍 | Oscar winner',
  avatarAsset: 'assets/test2.jpg',
  coverImageAsset: 'assets/test4.jpg',
  friendsCount: 320,
  accountType: AccountType.normal,
  privacyType: PrivacyType.open,
  knockStatus: KnockStatus.theyKnockedYou,
);

/// All demo users for easy lookup
const List<UserModel> allDemoUsers = [
  demoZaynMalik,
  demoJustinBieber,
  demoSumanPatra,
  demoSaptarshiNayak,
  demoAryaLayek,
  demoLeonardoDiCaprio,
];

UserModel? findDemoUserById(String id) {
  if (demoOwnUser.id == id) return demoOwnUser;
  for (final u in allDemoUsers) {
    if (u.id == id) return u;
  }
  return null;
}

/// Find a full demo UserModel by username. Returns null if not found.
UserModel? findDemoUserByUsername(String username) {
  for (final u in allDemoUsers) {
    if (u.username == username) return u;
  }
  return null;
}
