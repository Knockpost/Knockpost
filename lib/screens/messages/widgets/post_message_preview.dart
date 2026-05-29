import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import '../../../widgets/knockpost_avatar.dart';
import '../../single_post_screen.dart';

class PostMessagePreview extends StatefulWidget {
  final String postId;
  final bool isMe;

  const PostMessagePreview({
    super.key,
    required this.postId,
    required this.isMe,
  });

  @override
  State<PostMessagePreview> createState() => _PostMessagePreviewState();
}

class _PostMessagePreviewState extends State<PostMessagePreview> {
  PostModel? _post;
  UserModel? _author;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    try {
      final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      if (!postDoc.exists) {
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
        return;
      }
      
      final postData = postDoc.data() as Map<String, dynamic>;
      final post = PostModel.fromMap(postData, postDoc.id);
      
      final authorData = await DatabaseService.instance.getUserProfile(post.authorId);
      if (authorData != null) {
        final author = UserModel.fromMap(authorData, post.authorId);
        if (mounted) {
          setState(() {
            _post = post;
            _author = author;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        height: 140,
        width: 220,
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: KnockPostLoadingIndicator()),
      );
    }

    if (_hasError || _post == null || _author == null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          "Post unavailable",
          style: TextStyle(
            color: widget.isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black54),
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
      );
    }

    final hasImage = _post!.imagePaths.isNotEmpty || _post!.coverImagePath != null;
    final imageUrl = _post!.coverImagePath ?? (_post!.imagePaths.isNotEmpty ? _post!.imagePaths.first : null);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SinglePostScreen(
              post: _post!,
              author: _author!,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 240,
        decoration: BoxDecoration(
          color: isDark ? Colors.black12 : Colors.white70,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Author Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  KnockPostAvatar(
                    url: _author!.avatarAsset,
                    radius: 12,
                    name: _author!.displayName,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _author!.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Image Preview (if any)
            if (hasImage && imageUrl != null)
              Container(
                height: 180,
                width: double.infinity,
                color: isDark ? Colors.black26 : Colors.black12,
                child: imageUrl.startsWith('http') 
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Image.asset(imageUrl, fit: BoxFit.cover),
              ),
              
            // Caption Preview
            if (_post!.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _post!.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isMe ? Colors.white.withValues(alpha: 0.9) : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else if (!hasImage)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Thought post",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: widget.isMe ? Colors.white54 : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
