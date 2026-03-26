import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'chat_screen.dart';

class _UserEntry {
  final String name;
  final String username;
  final String avatarAsset;

  const _UserEntry({
    required this.name,
    required this.username,
    required this.avatarAsset,
  });
}

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<_UserEntry> _allUsers = [
    _UserEntry(name: "Arya Layek", username: "arya.layek", avatarAsset: "assets/test1.jpg"),
    _UserEntry(name: "Justin Bieber", username: "justin.bieber", avatarAsset: "assets/test2.jpg"),
    _UserEntry(name: "Leonardo DiCaprio", username: "leo.dicaprio", avatarAsset: "assets/test2.jpg"),
    _UserEntry(name: "Saptarshi Nayak", username: "saptarshi.nayak", avatarAsset: "assets/test4.jpg"),
    _UserEntry(name: "Suman Patra", username: "suman.patra", avatarAsset: "assets/test3.jpg"),
    _UserEntry(name: "Zayn Malik", username: "zayn.malik", avatarAsset: "assets/test1.jpg"),
  ];

  List<_UserEntry> get _filteredUsers {
    if (_searchQuery.isEmpty) return _allUsers;
    final query = _searchQuery.toLowerCase();
    return _allUsers.where((u) =>
        u.name.toLowerCase().contains(query) ||
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
                      return _UserTile(
                        name: user.name,
                        username: user.username,
                        avatarAsset: user.avatarAsset,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String name;
  final String username;
  final String avatarAsset;

  const _UserTile({
    required this.name,
    required this.username,
    required this.avatarAsset,
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
              userName: name,
              userAvatar: avatarAsset,
              userUsername: username,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: AssetImage(avatarAsset),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "@$username",
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
