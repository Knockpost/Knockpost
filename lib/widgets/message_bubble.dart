import 'package:flutter/material.dart';

import '../models/message.dart';
import '../models/user_model.dart';
import 'knockpost_avatar.dart';

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
      topLeft: Radius.circular(isUserSide ? 20 : (showSenderMeta ? 20 : 10)),
      topRight: Radius.circular(isUserSide ? (showSenderMeta ? 20 : 10) : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );

    // Responsive max width: 72% of screen width
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;

    Widget buildAvatar() => GestureDetector(
          onTap: onUserTap,
          child: KnockpostAvatar(
            url: sender.avatarAsset,
            radius: 13,
            name: sender.displayName,
          ),
        );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        top: showSenderMeta ? 16 : 6,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment:
            isUserSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderMeta)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment:
                    isUserSide ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: isUserSide
                    ? <Widget>[
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: subtleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 7),
                        GestureDetector(
                          onTap: onUserTap,
                          child: Text(
                            sender.username,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        buildAvatar(),
                      ]
                    : <Widget>[
                        buildAvatar(),
                        const SizedBox(width: 7),
                        GestureDetector(
                          onTap: onUserTap,
                          child: Text(
                            sender.username,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: subtleColor,
                            fontSize: 11,
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
