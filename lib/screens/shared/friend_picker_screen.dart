import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/current_user_service.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/knockpost_avatar.dart';

Future<List<String>?> showFriendPickerScreen(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Color accentColor,
  List<String> initiallySelected = const [],
  bool useExcludeMode = false,
}) {
  return Navigator.push<List<String>>(
    context,
    MaterialPageRoute(
      builder: (_) => FriendPickerScreen(
        title: title,
        subtitle: subtitle,
        accentColor: accentColor,
        initiallySelected: initiallySelected,
        useExcludeMode: useExcludeMode,
      ),
      fullscreenDialog: true, // Slides up from bottom like WhatsApp
    ),
  );
}

class FriendPickerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<String> initiallySelected;
  final bool useExcludeMode;

  const FriendPickerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.initiallySelected = const [],
    this.useExcludeMode = false,
  });

  @override
  State<FriendPickerScreen> createState() => _FriendPickerScreenState();
}

class _FriendPickerScreenState extends State<FriendPickerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  
  // Use demo users as friends for now
  List<UserModel> _friends = [];
  List<UserModel> _filteredFriends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _selectedIds.addAll(widget.initiallySelected);

    _searchCtrl.addListener(() {
      final query = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        if (query.isEmpty) {
          _filteredFriends = _friends;
        } else {
          _filteredFriends = _friends
              .where((u) =>
                  u.displayName.toLowerCase().contains(query) ||
                  u.username.toLowerCase().contains(query))
              .toList();
        }
      });
    });
  }

  Future<void> _fetchUsers() async {
    final currentUserId = CurrentUserService.instance.currentUser?.id;
    final fetchedUsers = await DatabaseService.instance.getSuggestedUsers(
      excludeUid: currentUserId,
      limitCount: 50, // Get a reasonable amount of people to pick from
    );
    
    if (mounted) {
      setState(() {
        _friends = List.of(fetchedUsers);
        _friends.sort((a, b) => a.displayName.compareTo(b.displayName));
        _filteredFriends = _friends;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    KnockHaptics.tap();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAll() {
    KnockHaptics.tap();
    setState(() {
      if (_selectedIds.length == _friends.length) {
        _selectedIds.clear(); // Deselect all
      } else {
        _selectedIds.addAll(_friends.map((e) => e.id)); // Select all
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF8F9FA);
    
    final isAllSelected = _selectedIds.length == _friends.length && _friends.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${_selectedIds.length} friends selected',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: isAllSelected ? 'Deselect All' : 'Select All',
            onPressed: _toggleAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          // ── Subtitle Header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            child: Text(
              widget.subtitle.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.accentColor,
                letterSpacing: 1,
              ),
            ),
          ),

          // ── Friends List ────────────────────────────────────────────────
          Expanded(
            child: _isLoading 
              ? const Center(child: KnockpostLoadingIndicator())
              : _filteredFriends.isEmpty
                ? Center(
                    child: Text(
                      'No friends found.',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final user = _filteredFriends[index];
                      final isSelected = _selectedIds.contains(user.id);

                      return InkWell(
                        onTap: () => _toggleSelection(user.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // Checkbox
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected ? widget.accentColor : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.accentColor
                                        : (isDark ? Colors.white38 : Colors.black26),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        widget.useExcludeMode
                                            ? Icons.close_rounded
                                            : Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              // Avatar
                              KnockpostAvatar(
                                url: user.avatarAsset,
                                radius: 22,
                                name: user.displayName,
                              ),
                              const SizedBox(width: 12),
                              // Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${user.username}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      // ── Floating Action Done Button ────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.accentColor,
        elevation: 4,
        onPressed: () {
          KnockHaptics.tap();
          Navigator.pop(context, _selectedIds.toList());
        },
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
