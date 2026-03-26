import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../profile/other_profile_screen.dart';

enum ConnectionStatus { knock, requested, knocked, knockBack }

class MockUser {
  final String id;
  final String name;
  final String username;
  final String profilePic;
  final String coverPic;
  final String bio;
  final int friendsCount;
  final PrivacyType privacyType;
  final AccountType accountType;
  final CreatorRank rank;
  final List<PostModel> posts;
  final List<String> mutualFriendsWhoKnocked;
  ConnectionStatus connectionStatus;

  MockUser({
    required this.id,
    required this.name,
    required this.username,
    required this.profilePic,
    required this.coverPic,
    required this.bio,
    required this.friendsCount,
    required this.privacyType,
    required this.accountType,
    required this.rank,
    required this.posts,
    this.mutualFriendsWhoKnocked = const [],
    this.connectionStatus = ConnectionStatus.knock,
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';
  Timer? _debounce;

  late List<MockUser> _allUsers;
  List<MockUser> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _allUsers = [
      MockUser(
        id: 'u01',
        name: 'Zayn Malik',
        username: 'zayn.malik',
        profilePic: 'assets/test1.jpg',
        coverPic: 'assets/test2.jpg',
        bio: 'Singer & songwriter 🎤 | Former 1D | Night Thoughts',
        friendsCount: 52400,
        privacyType: PrivacyType.open,
        accountType: AccountType.creator,
        rank: CreatorRank.impact,
        posts: _buildDemoPosts('u01', seed: 1),
        mutualFriendsWhoKnocked: const ['assets/test2.jpg', 'assets/test3.jpg', 'assets/test4.jpg'],
      ),
      MockUser(
        id: 'u02',
        name: 'Justin Bieber',
        username: 'justin.bieber',
        profilePic: 'assets/test2.jpg',
        coverPic: 'assets/test3.jpg',
        bio: 'Music is my life 🎶 | Believer',
        friendsCount: 84200,
        privacyType: PrivacyType.open,
        accountType: AccountType.creator,
        rank: CreatorRank.plus,
        posts: _buildDemoPosts('u02', seed: 2),
        mutualFriendsWhoKnocked: const ['assets/test1.jpg', 'assets/test4.jpg'],
      ),
      MockUser(
        id: 'u03',
        name: 'Suman Patra',
        username: 'suman.patra',
        profilePic: 'assets/test3.jpg',
        coverPic: 'assets/test4.jpg',
        bio: 'Keep it private 🔒',
        friendsCount: 142,
        privacyType: PrivacyType.private,
        accountType: AccountType.normal,
        rank: CreatorRank.echo,
        posts: _buildDemoPosts('u03', seed: 3),
      ),
      MockUser(
        id: 'u04',
        name: 'Saptarshi Nayak',
        username: 'saptarshi.nayak',
        profilePic: 'assets/test4.jpg',
        coverPic: 'assets/test1.jpg',
        bio: 'Open book 📖 | Exploring life one day at a time',
        friendsCount: 890,
        privacyType: PrivacyType.open,
        accountType: AccountType.normal,
        rank: CreatorRank.echo,
        posts: _buildDemoPosts('u04', seed: 4),
        connectionStatus: ConnectionStatus.knocked,
      ),
      MockUser(
        id: 'u05',
        name: 'Arya Layek',
        username: 'arya.layek',
        profilePic: 'assets/test1.jpg',
        coverPic: 'assets/test3.jpg',
        bio: 'Creator & storyteller ✨ | Pro vibes',
        friendsCount: 15400,
        privacyType: PrivacyType.open,
        accountType: AccountType.creator,
        rank: CreatorRank.pro,
        posts: _buildDemoPosts('u05', seed: 5),
        mutualFriendsWhoKnocked: const ['assets/test2.jpg', 'assets/test3.jpg', 'assets/test4.jpg'],
      ),
      MockUser(
        id: 'u06',
        name: 'Leonardo DiCaprio',
        username: 'leo.dicaprio',
        profilePic: 'assets/test2.jpg',
        coverPic: 'assets/test4.jpg',
        bio: 'Actor & environmentalist 🌍 | Oscar winner',
        friendsCount: 320,
        privacyType: PrivacyType.open,
        accountType: AccountType.normal,
        rank: CreatorRank.echo,
        posts: _buildDemoPosts('u06', seed: 6),
        connectionStatus: ConnectionStatus.knockBack,
      ),
    ];
    _filteredUsers = _allUsers;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<PostModel> _buildDemoPosts(String authorId, {required int seed}) {
    final now = DateTime.now();
    const pool = [
      'assets/test1.jpg',
      'assets/test2.jpg',
      'assets/test3.jpg',
      'assets/test4.jpg',
    ];
    final first = pool[seed % pool.length];
    final second = pool[(seed + 1) % pool.length];
    final third = pool[(seed + 2) % pool.length];

    return [
      PostModel(
        id: '${authorId}_recent',
        authorId: authorId,
        type: PostType.media,
        duration: PostDuration.h24,
        imagePaths: [first, second],
        text: 'Evening dump from today.',
        createdAt: now.subtract(Duration(hours: 2 + seed)),
        likes: 12 + seed * 3,
        views: 90 + seed * 12,
      ),
      PostModel(
        id: '${authorId}_showcase',
        authorId: authorId,
        type: PostType.media,
        duration: PostDuration.lifetime,
        imagePaths: [third],
        text: 'One of my favourite captures.',
        createdAt: now.subtract(Duration(days: 2 + seed)),
        likes: 35 + seed * 4,
        views: 180 + seed * 20,
      ),
      PostModel(
        id: '${authorId}_text',
        authorId: authorId,
        type: PostType.text,
        duration: PostDuration.lifetime,
        text: 'Small note ${seed + 1}: keep moving, keep creating.',
        createdAt: now.subtract(Duration(hours: 10 + seed)),
        likes: 8 + seed,
        views: 60 + seed * 8,
      ),
    ];
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        _applyFilters();
      });
    });
  }

  void _applyFilters() {
    List<MockUser> results = _allUsers;

    if (_searchQuery.isNotEmpty) {
      results = results
          .where(
            (user) =>
                user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                user.username.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    _filteredUsers = results;
  }

  KnockStatus _toKnockStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.knock:
        return KnockStatus.none;
      case ConnectionStatus.requested:
        return KnockStatus.pending;
      case ConnectionStatus.knocked:
        return KnockStatus.knocked;
      case ConnectionStatus.knockBack:
        return KnockStatus.theyKnockedYou;
    }
  }

  ConnectionStatus _toConnectionStatus(KnockStatus status) {
    switch (status) {
      case KnockStatus.none:
        return ConnectionStatus.knock;
      case KnockStatus.pending:
        return ConnectionStatus.requested;
      case KnockStatus.knocked:
      case KnockStatus.mutualKnocked:
        return ConnectionStatus.knocked;
      case KnockStatus.theyKnockedYou:
        return ConnectionStatus.knockBack;
    }
  }

  bool _isEffectivelyOpen(MockUser user) =>
      user.accountType == AccountType.creator ||
      user.privacyType == PrivacyType.open;

  Widget _buildTrailingButton(MockUser user, bool isDark) {
    final greyBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E5);
    final greyFg = isDark ? Colors.white : Colors.black87;
    final primaryBg = isDark ? Colors.white : Colors.black;
    final primaryFg = isDark ? Colors.black : Colors.white;

    late final String label;
    late final Color bg;
    late final Color fg;

    switch (user.connectionStatus) {
      case ConnectionStatus.knock:
        label = 'Knock';
        bg = primaryBg;
        fg = primaryFg;
        break;
      case ConnectionStatus.requested:
        label = 'Pending';
        bg = greyBg;
        fg = greyFg;
        break;
      case ConnectionStatus.knocked:
        label = 'Knocked';
        bg = greyBg;
        fg = greyFg;
        break;
      case ConnectionStatus.knockBack:
        label = 'Knock Back';
        bg = primaryBg;
        fg = primaryFg;
        break;
    }

    return GestureDetector(
      onTap: () {
        KnockHaptics.tap();
        setState(() {
          switch (user.connectionStatus) {
            case ConnectionStatus.knock:
              user.connectionStatus = _isEffectivelyOpen(user)
                  ? ConnectionStatus.knocked
                  : ConnectionStatus.requested;
              break;
            case ConnectionStatus.requested:
            case ConnectionStatus.knocked:
              user.connectionStatus = ConnectionStatus.knock;
              break;
            case ConnectionStatus.knockBack:
              user.connectionStatus = ConnectionStatus.knocked;
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        titleSpacing: 16,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            style: TextStyle(color: textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search Knockpost',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        _searchFocus.unfocus();
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundImage: AssetImage(user.profilePic),
                          onBackgroundImageError: (_, __) {},
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                        title: Text(
                          user.username,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          user.name,
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        trailing: _buildTrailingButton(user, isDark),
                        onTap: () {
                          KnockHaptics.tap();
                          final userModel = UserModel(
                            id: user.id,
                            displayName: user.name,
                            username: user.username,
                            bio: user.bio,
                            avatarAsset: user.profilePic,
                            coverImageAsset: user.coverPic,
                            friendsCount: user.friendsCount,
                            accountType: user.accountType,
                            privacyType: user.privacyType,
                            rank: user.rank,
                            mutualFriendsWhoKnocked:
                                user.mutualFriendsWhoKnocked,
                            knockStatus: _toKnockStatus(user.connectionStatus),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OtherProfileScreen(
                                user: userModel,
                                posts: user.posts,
                                onKnockStatusChanged: (status) {
                                  setState(() {
                                    user.connectionStatus = _toConnectionStatus(
                                      status,
                                    );
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
