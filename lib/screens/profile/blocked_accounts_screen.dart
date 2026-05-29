import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/knockpost_avatar.dart';
import '../../widgets/system_nav_bar_fill.dart';

import '../../services/current_user_service.dart';
import '../../services/database_service.dart';

class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  List<UserModel> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final me = CurrentUserService.instance.currentUser;
    if (me == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final doc = await DatabaseService.instance.usersCollection.doc(me.id).get();
      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }
      
      final myUser = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      if (myUser.blockedUsers.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final List<UserModel> users = [];
      for (final uid in myUser.blockedUsers) {
        final blockedDoc = await DatabaseService.instance.usersCollection.doc(uid).get();
        if (blockedDoc.exists) {
          users.add(UserModel.fromMap(blockedDoc.data() as Map<String, dynamic>, blockedDoc.id));
        }
      }
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  void _unblockUser(UserModel user) {
    KnockHaptics.selection();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white70 : Colors.black87;

    showDialog(
      context: context,
      builder: (diagContext) {
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Unblock @${user.username}?',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          content: Text(
            'They will now be able to find your profile and knock you. They won\'t be notified that you unblocked them.',
            style: TextStyle(
              color: subColor,
              height: 1.4,
              fontSize: 14.5,
            ),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(diagContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                KnockHaptics.impact();
                final me = CurrentUserService.instance.currentUser;
                if (me != null) {
                  DatabaseService.instance.unblockUser(myUid: me.id, targetUid: user.id);
                }
                setState(() {
                  _blockedUsers.remove(user);
                });
                Navigator.pop(diagContext);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You unblocked @${user.username}'),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Unblock',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;

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
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Blocked accounts',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.3,
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Text(
                    'Accounts you block won\'t be able to see your profile, posts, or knocks. KnockPost won\'t let them know you blocked them.',
                    style: TextStyle(
                      fontSize: 14,
                      color: subColor,
                      height: 1.4,
                    ),
                  ),
                ),
                
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: KnockPostLoadingIndicator(),
                        )
                      : _blockedUsers.isEmpty
                          ? Center(
                              child: Text(
                                'No blocked accounts',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: subColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _blockedUsers.length,
                          itemBuilder: (context, index) {
                            final user = _blockedUsers[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  KnockPostAvatar(
                                    url: user.avatarAsset,
                                    radius: 26,
                                    name: user.displayName,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.username,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          user.displayName,
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => _unblockUser(user),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2C2C2C)
                                            : const Color(0xFFE5E5E5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Unblock',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SystemNavBarFill(color: bg),
            ),
          ],
        ),
      ),
    );
  }
}
