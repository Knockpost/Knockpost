import 'package:flutter/material.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({super.key});

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {

  final Map<String, List<String>> interestMap = {

    "Culture": [
      "Cultural Commentary",
      "Subcultures",
      "Festivals",
      "Pop Culture",
      "Social Issues"
    ],
    "Technology": [
      "AI",
      "Startups",
      "Programming",
      "Cybersecurity",
      "Gadgets"
    ],
    "Business": [
      "Finance",
      "Investing",
      "Economy",
      "Entrepreneurship",
      "Marketing"
    ],
    "Science": [
      "Space",
      "Psychology",
      "Biology",
      "Physics",
      "Environment"
    ],
    "Music": [
      "Indie",
      "Hip Hop",
      "Classical",
      "Pop",
      "Electronic"
    ],
    "Sports": [
      "Football",
      "Cricket",
      "Basketball",
      "Tennis",
      "Fitness"
    ],
    "Art": [
      "Illustration",
      "Painting",
      "Photography",
      "Design",
      "Street Art"
    ],
    "Movies": [
      "Hollywood",
      "Bollywood",
      "Anime",
      "Documentary",
      "Thriller"
    ],
    "Books": [
      "Fiction",
      "Non-fiction",
      "Self Help",
      "Fantasy",
      "Poetry"
    ],
    "Lifestyle": [
      "Minimalism",
      "Travel",
      "Productivity",
      "Mindfulness",
      "Habits"
    ],
    "Health": [
      "Nutrition",
      "Mental Health",
      "Workout",
      "Yoga",
      "Sleep"
    ],
    "Food": [
      "Cooking",
      "Street Food",
      "Vegan",
      "Desserts",
      "Coffee"
    ],
    "Politics": [
      "World Politics",
      "Indian Politics",
      "Policy",
      "Geopolitics",
      "Debates"
    ],
    "Gaming": [
      "PC Gaming",
      "Console",
      "Esports",
      "Mobile Gaming",
      "Indie Games"
    ],
    "Fashion": [
      "Streetwear",
      "Luxury",
      "Minimal",
      "Vintage",
      "Sneakers"
    ],
  };

  final Set<String> selectedInterests = {};
  final Set<String> expandedCategories = {}; // ✅ FIXED HERE

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 10),

              const Text(
                "Choose your interests",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Select topics to personalize your experience.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 30),

              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: buildInterestChips(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                height: 58,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    "Continue",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  List<Widget> buildInterestChips() {

    List<Widget> widgets = [];

    interestMap.forEach((category, subList) {

      widgets.add(buildChip(category, isMain: true));

      if (expandedCategories.contains(category)) {
        for (var sub in subList) {
          widgets.add(buildChip(sub, isMain: false));
        }
      }
    });

    return widgets;
  }

  Widget buildChip(String label, {required bool isMain}) {

    bool isSelected = selectedInterests.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {

          if (isMain) {
            if (expandedCategories.contains(label)) {
              expandedCategories.remove(label);
            } else {
              expandedCategories.add(label);
            }
          } else {
            if (isSelected) {
              selectedInterests.remove(label);
            } else {
              selectedInterests.add(label);
            }
          }

        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected || expandedCategories.contains(label)
              ? Colors.black
              : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected || expandedCategories.contains(label)
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}