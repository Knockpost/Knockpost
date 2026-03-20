import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/haptic_helper.dart';

// --- MOCK DATA MODEL ---
enum ConnectionStatus { knock, knocked }

class MockUser {
  final String id;
  final String name;
  final String username;
  final String profilePic;
  ConnectionStatus connectionStatus;
  
  MockUser({
    required this.id,
    required this.name,
    required this.username,
    required this.profilePic,
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
  
  String _searchQuery = "";
  Timer? _debounce;
  
  // Mock Database
  late List<MockUser> _allUsers;
  List<MockUser> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _allUsers = [
      MockUser(
        id: "1", name: "Rahul Sharma", username: "rahul_sharma", 
        profilePic: "assets/test1.jpg", connectionStatus: ConnectionStatus.knock, 
      ),
      MockUser(
        id: "2", name: "Riya Desai", username: "riya.d", 
        profilePic: "assets/test2.jpg", connectionStatus: ConnectionStatus.knock, 
      ),
      MockUser(
        id: "3", name: "Rishabh Pant", username: "rishab", 
        profilePic: "assets/test3.jpg", connectionStatus: ConnectionStatus.knocked, 
      ),
      MockUser(
        id: "4", name: "Akash Singh", username: "akash_s", 
        profilePic: "assets/test4.jpg", connectionStatus: ConnectionStatus.knock, 
      ),
      MockUser(
        id: "5", name: "Anita Roy", username: "anita.r", 
        profilePic: "assets/test1.jpg", connectionStatus: ConnectionStatus.knock, 
      ),
      MockUser(
        id: "6", name: "Rohan Das", username: "rohan_das", 
        profilePic: "assets/test2.jpg", connectionStatus: ConnectionStatus.knock, 
      ),
      MockUser(
        id: "7", name: "Priya Menon", username: "priya_m", 
        profilePic: "assets/test3.jpg", connectionStatus: ConnectionStatus.knock, 
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
      results = results.where((user) => 
        user.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        user.username.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    _filteredUsers = results;
  }

  Widget _buildTrailingButton(MockUser user, bool isDark) {
    if (user.connectionStatus == ConnectionStatus.knocked) {
      return GestureDetector(
        onTap: () {
          // If already knocked, tapping it can cancel it
          KnockHaptics.tap();
          setState(() {
            user.connectionStatus = ConnectionStatus.knock;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text("Knocked", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          KnockHaptics.tap();
          setState(() {
            user.connectionStatus = ConnectionStatus.knocked;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text("Knock", style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
    }
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
              hintText: "Search Knockpost",
              hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 15),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey[600], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: isDark ? Colors.grey[500] : Colors.grey[600], size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged("");
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
                      "No results found",
                      style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: CircleAvatar(
                          radius: 20, // Smaller profile picture size
                          backgroundImage: AssetImage(user.profilePic),
                          onBackgroundImageError: (_, __) {},
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                        ),
                        title: Text(
                          user.username,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          user.name,
                          style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
                        ),
                        trailing: _buildTrailingButton(user, isDark),
                        onTap: () {
                          KnockHaptics.tap();
                          // Navigate to user profile
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
