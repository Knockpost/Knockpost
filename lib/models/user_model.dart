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
  final String bio;
  final String? avatarAsset; // null = show default avatar
  final String? coverImageAsset; // background cover image
  final int friendsCount;

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

  const UserModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.bio,
    this.avatarAsset,
    this.coverImageAsset,
    this.friendsCount = 0,
    this.accountType = AccountType.normal,
    this.privacyType = PrivacyType.open,
    this.rank = CreatorRank.echo,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalKnocksReceived = 0,
    this.knockStatus = KnockStatus.none,
    this.isOwnProfile = false,
  });

  /// Whether this profile's content is visible to the current viewer
  bool get isContentVisible {
    if (isOwnProfile) return true;
    if (accountType == AccountType.creator) return true;
    if (privacyType == PrivacyType.open) return true;
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
    String? coverImageAsset,
    int? friendsCount,
    AccountType? accountType,
    PrivacyType? privacyType,
    CreatorRank? rank,
    int? totalViews,
    int? totalLikes,
    int? totalKnocksReceived,
    KnockStatus? knockStatus,
    bool? isOwnProfile,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      coverImageAsset: coverImageAsset ?? this.coverImageAsset,
      friendsCount: friendsCount ?? this.friendsCount,
      accountType: accountType ?? this.accountType,
      privacyType: privacyType ?? this.privacyType,
      rank: rank ?? this.rank,
      totalViews: totalViews ?? this.totalViews,
      totalLikes: totalLikes ?? this.totalLikes,
      totalKnocksReceived: totalKnocksReceived ?? this.totalKnocksReceived,
      knockStatus: knockStatus ?? this.knockStatus,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
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

const demoCreatorUser = UserModel(
  id: 'creator01',
  displayName: 'Riya Chakraborty',
  username: 'riya.creates',
  bio: 'Photographer & visual storyteller 📸 | Based in Mumbai',
  avatarAsset: 'assets/test4.jpg',
  coverImageAsset: 'assets/test1.jpg',
  friendsCount: 15400,
  accountType: AccountType.creator,
  rank: CreatorRank.pro,
  totalViews: 84000,
  totalLikes: 6200,
  totalKnocksReceived: 940,
);

const demoPrivateUser = UserModel(
  id: 'private01',
  displayName: 'Sneha Roy',
  username: 'sneha.r',
  bio: 'Keep it private 🔒',
  avatarAsset: 'assets/test2.jpg',
  coverImageAsset: 'assets/test3.jpg',
  friendsCount: 142,
  accountType: AccountType.normal,
  privacyType: PrivacyType.private,
  knockStatus: KnockStatus.none,
);

const demoKnockedUser = UserModel(
  id: 'knocked01',
  displayName: 'Dev Sharma',
  username: 'dev.s',
  bio: 'Music | Movies | Making memes',
  avatarAsset: 'assets/test3.jpg',
  coverImageAsset: 'assets/test4.jpg',
  friendsCount: 890,
  accountType: AccountType.normal,
  privacyType: PrivacyType.private,
  knockStatus: KnockStatus.knocked,
);
