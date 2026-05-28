import 'package:flutter/material.dart';
import '../../../../models/daily_glimpse_card_model.dart';
import '../../../../models/post_model.dart';
import '../../../../models/user_model.dart';
import '../../../../widgets/staggered_entry_animation.dart';
import 'daily_glimpse_card_widget.dart';

class DailyGlimpseStrip extends StatelessWidget {
  final List<DailyGlimpseCard> dailyCards;
  final List<PostModel> allUserGlimpses;
  final UserModel user;

  const DailyGlimpseStrip({
    super.key,
    required this.dailyCards,
    required this.allUserGlimpses,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyCards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: SizedBox(
        height: 220, // Same size as old profile glimpse strip
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(), // Allows overscroll to pass to TabBarView
          itemCount: dailyCards.length,
          itemBuilder: (context, index) {
            final card = dailyCards[index];
            return StaggeredEntryAnimation(
              index: index,
              delay: const Duration(milliseconds: 40),
              child: DailyGlimpseCardWidget(
                card: card,
                user: user,
                allUserGlimpses: allUserGlimpses,
                allDailyCards: dailyCards,
                cardIndex: index,
              ),
            );
          },
        ),
      ),
    );
  }
}
