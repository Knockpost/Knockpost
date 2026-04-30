import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/image_helper.dart';
import 'chat_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<UserModel> _allUsers = [
    demoAryaLayek,
    demoJustinBieber,
    demoLeonardoDiCaprio,
    demoSaptarshiNayak,
    demoSumanPatra,
    demoZaynMalik,
  ];

  List<UserModel> get _filteredUsers {
    if (_searchQuery.isEmpty) return _allUsers;
    final query = _searchQuery.toLowerCase();
    return _allUsers.where((u) =>
        u.displayName.toLowerCase().contains(query) ||
        u.username.toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
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
            CircleAvatar(
              radius: 26,
              backgroundImage: ImageHelper.resolveImage(user.avatarAsset),
              backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              child: user.avatarAsset == null
                  ? Icon(Icons.person, color: isDark ? Colors.white54 : Colors.black38)
                  : null,
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
                      fontWeight: FontWeight.w600,
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
