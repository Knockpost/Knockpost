import 'dart:io';

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../profile/other_profile_screen.dart';
import '../../services/database_service.dart';
import '../../services/post_service.dart';
import '../../widgets/knockpost_avatar.dart';

class MessageInfoScreen extends StatefulWidget {
  /// The real Firebase UID of the other chat participant.
  final String userId;
  final String userName;
  final String userAvatar;
  final String userUsername;

  const MessageInfoScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.userUsername,
  });

  @override
  State<MessageInfoScreen> createState() => _MessageInfoScreenState();
}

class _MessageInfoScreenState extends State<MessageInfoScreen> {
  /// Cached real user fetched from Firestore (null while loading).
  UserModel? _resolvedUser;
  bool _isLoadingUser = false;
  bool _hasFetchError = false;

  @override
  void initState() {
    super.initState();
    _fetchRealUser();
  }

  /// Fetch the real UserModel from Firestore using the Firebase UID.
  Future<void> _fetchRealUser() async {
    setState(() {
      _isLoadingUser = true;
      _hasFetchError = false;
    });

    debugPrint('[MessageInfoScreen] Fetching real user for uid=${widget.userId}, '
        'username=${widget.userUsername}');

    try {
      final user = await DatabaseService.instance.getUserById(widget.userId);
      if (mounted) {
        setState(() {
          _resolvedUser = user;
          _isLoadingUser = false;
          _hasFetchError = user == null;
        });

        if (user != null) {
          debugPrint('[MessageInfoScreen] ✅ Resolved user: '
              'id=${user.id}, username=${user.username}, displayName=${user.displayName}');
        } else {
          debugPrint('[MessageInfoScreen] ⚠️ User not found for uid=${widget.userId}');
        }
      }
    } catch (e) {
      debugPrint('[MessageInfoScreen] ❌ Error fetching user: $e');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
          _hasFetchError = true;
        });
      }
    }
  }

  /// Navigate to the real user's full profile screen.
  void _openRealProfile() {
    final user = _resolvedUser;
    if (user == null) {
      // Shouldn't happen — button is disabled while loading/error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load profile. Please try again.')),
      );
      return;
    }

    debugPrint('[MessageInfoScreen] Opening profile for uid=${user.id}, '
        'username=${user.username}');

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final cardColor = isDark ? const Color(0xff1C1C1E) : const Color(0xfff5f7fb);
    final textColor = isDark ? Colors.white : Colors.black;

    // Use resolved data if available, otherwise fall back to passed-in data for display
    final displayName = _resolvedUser?.displayName ?? widget.userName;
    final displayUsername = _resolvedUser?.username ?? widget.userUsername;
    final displayAvatar = _resolvedUser?.avatarAsset ?? widget.userAvatar;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Chat Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),

            /// USER PROFILE — tappable to open full profile
            GestureDetector(
              onTap: _isLoadingUser || _hasFetchError ? null : _openRealProfile,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0A7CFF).withValues(alpha: 0.3),
                        width: 3,
                      ),
                    ),
                    child: KnockpostAvatar(
                      url: displayAvatar,
                      radius: 60,
                      name: displayName,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Loading indicator below avatar
                  if (_isLoadingUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                      ),
                    ),

                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  Text(
                    "@$displayUsername",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),

                  // Error state
                  if (_hasFetchError && !_isLoadingUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: _fetchRealUser,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to retry',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            /// OPTIONS CONTAINER
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildOption(
                    icon: Icons.notifications_off_outlined,
                    text: "Mute Notifications",
                    textColor: textColor,
                  ),
                  _buildDivider(isDark),
                  _buildOption(
                    icon: Icons.photo_outlined, 
                    text: "Shared Media",
                    textColor: textColor,
                  ),
                  _buildDivider(isDark),
                  _buildOption(
                    icon: Icons.search_rounded, 
                    text: "Search in Chat",
                    textColor: textColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// DANGER OPTIONS CONTAINER
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildOption(
                    icon: Icons.block,
                    text: "Block User",
                    textColor: Colors.redAccent,
                  ),
                  _buildDivider(isDark),
                  _buildOption(
                    icon: Icons.report_outlined,
                    text: "Report User",
                    textColor: Colors.redAccent,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1, 
      thickness: 0.5, 
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      indent: 56, // Align with text
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String text,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500, size: 20),
          ],
        ),
      ),
    );
  }
}
