import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/database_service.dart';
import '../../services/current_user_service.dart';
import '../../services/connection_service.dart';
import '../../widgets/people_suggestion_strip.dart';
import '../../widgets/system_nav_bar_fill.dart';
import '../../services/post_service.dart';
import '../../utils/global_knock_state.dart';
import '../../utils/global_dismiss_state.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/knockpost_avatar.dart';
import '../profile/other_profile_screen.dart';
import '../profile/widgets/knock_button.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  const DiscoverPeopleScreen({super.key});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    GlobalDismissState.dismissedUserIds.addListener(_rebuild);
  }

  Future<void> _fetchUsers() async {
    final currentUserId = CurrentUserService.instance.currentUser?.id;
    final fetchedUsers = await DatabaseService.instance.getSuggestedUsers(
      excludeUid: currentUserId,
      limitCount: 50,
    );
    
    if (!mounted) return;

    final statuses = await Future.wait(fetchedUsers.map((u) async {
      var status = GlobalKnockState.getNotifier(u.id, u.knockStatus).value;
      if (status == KnockStatus.none) {
        status = await ConnectionService.instance.getKnockStatus(u.id);
        GlobalKnockState.getNotifier(u.id, status).value = status;
      }
      return status;
    }));

    final validUsers = <UserModel>[];
    for (int i = 0; i < fetchedUsers.length; i++) {
      final u = fetchedUsers[i];
      if (GlobalDismissState.isDismissed(u.id)) continue;
      
      final status = statuses[i];
      if (status != KnockStatus.knocked &&
          status != KnockStatus.pending &&
          status != KnockStatus.mutualKnocked) {
        validUsers.add(u);
      }
    }

    if (mounted) {
      setState(() {
        _users = validUsers;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    GlobalDismissState.dismissedUserIds.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Filter out dismissed users
    final filteredUsers = _users
        .where((u) => !GlobalDismissState.isDismissed(u.id))
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              leadingWidth: 42,
              leading: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Discover People',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            body: _isLoading 
                ? const Center(child: KnockpostLoadingIndicator())
                : filteredUsers.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: filteredUsers.length,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        cacheExtent: 600,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 72,
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        ),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return _DiscoverUserTile(user: user);
                        },
                      ),
          ),
          SystemNavBarFill(color: bgColor),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_disabled_rounded, 
               size: 64, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            'No more suggestions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for more people!',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverUserTile extends StatelessWidget {
  final UserModel user;

  const _DiscoverUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? Colors.white54 : Colors.black54;

    return InkWell(
      onTap: () => _navigateToProfile(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            KnockpostAvatar(
              url: user.avatarAsset,
              radius: 28,
              name: user.displayName,
            ),
            const SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryColor,
                    ),
                  ),
                  if (user.mutualFriendsCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${user.mutualFriendsCount} mutual friends',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DiscoverKnockButton(user: user),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    KnockHaptics.impact();
                    GlobalDismissState.dismiss(user.id);
                  },
                  icon: Icon(Icons.close, 
                             size: 18, 
                             color: isDark ? Colors.white38 : Colors.black38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StreamBuilder<List<PostModel>>(
          stream: PostService.instance.getUserPosts(user.id),
          builder: (context, snapshot) {
            return OtherProfileScreen(
              user: user,
              posts: snapshot.data ?? [],
            );
          },
        ),
      ),
    );
  }
}

class _DiscoverKnockButton extends StatefulWidget {
  final UserModel user;
  const _DiscoverKnockButton({required this.user});

  @override
  State<_DiscoverKnockButton> createState() => _DiscoverKnockButtonState();
}

class _DiscoverKnockButtonState extends State<_DiscoverKnockButton> {
  late ValueNotifier<KnockStatus> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = GlobalKnockState.getNotifier(widget.user.id, widget.user.knockStatus);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KnockStatus>(
      valueListenable: _notifier,
      builder: (context, status, _) {

        return SizedBox(
          width: 96,
          child: KnockButton(
            initialStatus: status,
            userId: widget.user.id,
            privacyType: widget.user.privacyType,
            accountType: widget.user.accountType,
            isCompact: true,
            onStatusChanged: (newStatus) {
              _notifier.value = newStatus;
            },
          ),
        );
      },
    );
  }
}
