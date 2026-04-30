import 'package:flutter/material.dart';

import '../models/message.dart';
import '../models/user_model.dart';
import '../utils/image_helper.dart';

class MessageBubble extends StatelessWidget {
  final ReplyMessage message;
  final UserModel sender;
  final bool isUserSide;
  final bool showSenderMeta;
  final String timeLabel;
  final VoidCallback onUserTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.sender,
    required this.isUserSide,
    required this.showSenderMeta,
    required this.timeLabel,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final subtleColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF757575);
    final bubbleColor = isUserSide
        ? (isDark ? const Color(0xFF333D47) : const Color(0xFFE8EEF3))
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2));
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isUserSide ? 22 : (showSenderMeta ? 22 : 12)),
      topRight: Radius.circular(isUserSide ? (showSenderMeta ? 22 : 12) : 22),
      bottomLeft: const Radius.circular(22),
      bottomRight: const Radius.circular(22),
    );

    // Use ImageHelper to handle network URLs, local files, and assets
    final avatarImage = ImageHelper.resolveImage(sender.avatarAsset);

    Widget buildAvatar() => GestureDetector(
          onTap: onUserTap,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFEEEEEE),
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Icon(Icons.person_rounded, color: subtleColor, size: 16)
                : null,
          ),
        );

    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: textColor,
            fontSize: 14.5,
            height: 1.38,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showSenderMeta ? 18 : 8,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment:
            isUserSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderMeta)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment:
                    isUserSide ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: isUserSide
                    ? <Widget>[
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: subtleColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onUserTap,
                          child: Text(
                            sender.username,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        buildAvatar(),
                      ]
                    : <Widget>[
                        buildAvatar(),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onUserTap,
                          child: Text(
                            sender.username,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: subtleColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
              ),
            ),
          Row(
            mainAxisAlignment:
                isUserSide ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [bubble],
          ),
        ],
      ),
    );
  }
}
