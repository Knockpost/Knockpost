import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/knockpost_avatar.dart';
import 'chat_screen.dart';
import '../../services/connection_service.dart';
import '../../services/database_service.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<UserModel> _mutualConnections = [];
  StreamSubscription? _connectionSub;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });

    _loadData();
  }

  Future<void> _loadData() async {
    final uids = await ConnectionService.instance.getMutualConnectionUids();
    final users = <UserModel>[];
    for (final uid in uids) {
      final data = await DatabaseService.instance.getUserProfile(uid, useCache: true);
      if (data != null) users.add(UserModel.fromMap(data, uid));
    }
    if (mounted) {
      setState(() => _mutualConnections = users);
    }
  }

  List<UserModel> get _filteredUsers {
    if (_searchQuery.isEmpty) return _mutualConnections;
    final query = _searchQuery.toLowerCase();
    return _mutualConnections.where((u) =>
        u.displayName.toLowerCase().contains(query) ||
        u.username.toLowerCase().contains(query)).toList();
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final searchBgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        surfaceTintColor: bgColor,
        title: Text(
          "New Message", 
          style: TextStyle(
            color: textColor, 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          )
        ),
        iconTheme: IconThemeData(color: textColor),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: searchBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  hintText: "Search users",
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                          child: Icon(Icons.close_rounded,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 20),
                        )
                      : null,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Connections",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          /// USER LIST
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return _UserTile(user: user);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;

  const _UserTile({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return InkWell(
      onTap: () {
        KnockHaptics.tap();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUser: user,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            KnockpostAvatar(
              url: user.avatarAsset,
              radius: 26,
              name: user.displayName,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "@${user.username}",
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
