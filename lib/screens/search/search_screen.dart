import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/current_user_service.dart';
import '../../utils/haptic_helper.dart';
import '../profile/other_profile_screen.dart';
import '../../services/connection_service.dart';
import '../../utils/global_knock_state.dart';
import '../profile/widgets/knock_button.dart';
import '../../widgets/knockpost_refresh.dart';
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

  List<UserModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim() == _searchQuery.trim()) return;
      setState(() {
        _searchQuery = query.trim();
        if (_searchQuery.isEmpty) {
          _results = [];
          _hasSearched = false;
          _isLoading = false;
        }
      });
      if (_searchQuery.isNotEmpty) {
        _runSearch(_searchQuery);
      }
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isLoading = true);
    final currentUid = CurrentUserService.instance.currentUser?.id;
    final results = await DatabaseService.instance.searchUsers(
      query,
      excludeUid: currentUid,
    );
    List<UserModel> finalResults = results;
    
    if (currentUid != null) {
      final futures = results.map((user) async {
        final status = await ConnectionService.instance.getKnockStatus(user.id);
        GlobalKnockState.getNotifier(user.id, status).value = status;
        return user.copyWith(knockStatus: status);
      });
      finalResults = await Future.wait(futures);
    }

    if (!mounted) return;
    setState(() {
      _results = finalResults;
      _isLoading = false;
      _hasSearched = true;
    });
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
              hintText: 'Search people…',
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
                        setState(() {
                          _searchQuery = '';
                          _results = [];
                          _hasSearched = false;
                        });
                        _searchFocus.requestFocus();
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: _buildBody(isDark, textColor),
    );
  }

  Widget _buildBody(bool isDark, Color textColor) {
    // Empty state — no query typed yet
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 54,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Search for people',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Loading
    if (_isLoading) {
      return const KnockpostLoadingIndicator();
    }

    // No results
    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 54,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No results for "$_searchQuery"',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Results list
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return _UserResultTile(
          key: ValueKey(user.id),
          user: user,
          isDark: isDark,
        );
      },
    );
  }
}

// ─── User Result Tile ────────────────────────────────────────────────────────

class _UserResultTile extends StatefulWidget {
  final UserModel user;
  final bool isDark;

  const _UserResultTile({super.key, required this.user, required this.isDark});

  @override
  State<_UserResultTile> createState() => _UserResultTileState();
}

class _UserResultTileState extends State<_UserResultTile> {
  @override
  void initState() {
    super.initState();
  }



  Widget _buildTrailingButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KnockButton(
          userId: widget.user.id,
          initialStatus: widget.user.knockStatus,
          privacyType: widget.user.privacyType,
          accountType: widget.user.accountType,
          isCompact: true,
          isOwnProfile: widget.user.isOwnProfile,
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final isDark = widget.isDark;
    final avatar = widget.user.avatarAsset;

    ImageProvider? imageProvider;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http')) {
        imageProvider = NetworkImage(avatar);
      } else {
        imageProvider = AssetImage(avatar);
      }
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(
              Icons.person,
              size: 22,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildAvatar(),
      title: Text(
        widget.user.username,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        widget.user.displayName,
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: _buildTrailingButton(),
      onTap: () {
        KnockHaptics.tap();
        final currentStatus = GlobalKnockState.getNotifier(widget.user.id, widget.user.knockStatus).value;
        final updatedUser = widget.user.copyWith(knockStatus: currentStatus);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherProfileScreen(
              user: updatedUser,
              posts: const [],
              onKnockStatusChanged: (status) {
                // Handled natively by GlobalKnockState
              },
            ),
          ),
        );
      },
    );
  }
}
