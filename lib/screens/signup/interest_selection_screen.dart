import 'dart:io';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/current_user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home_screen.dart';
import '../login_screen.dart';

class InterestSelectionScreen extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  final String fullName;
  final String bio;
  final File? profileImage;
  final bool isGoogleSignup;

  const InterestSelectionScreen({
    super.key,
    required this.email,
    required this.username,
    required this.password,
    required this.fullName,
    required this.bio,
    this.profileImage,
    this.isGoogleSignup = false,
  });

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  bool isLoading = false;

  final Map<String, List<String>> interestMap = {
    "Culture": ["Cultural Commentary", "Subcultures", "Festival", "Pop Culture", "Social Issues"],
    "Technology": ["AI", "Startups", "Programming", "Cybersecurity", "Gadgets"],
    "Business": ["Finance", "Investing", "Economy", "Entrepreneurship", "Marketing"],
    "Science": ["Space", "Psychology", "Biology", "Physics", "Environment"],
    "Music": ["Indie", "Hip Hop", "Classical", "Pop", "Electronic"],
    "Sports": ["Football", "Cricket", "Basketball", "Tennis", "Fitness"],
    "Art": ["Illustration", "Painting", "Photography", "Design", "Street Art"],
    "Movies": ["Hollywood", "Bollywood", "Anime", "Documentary", "Thriller"],
    "Books": ["Fiction", "Non-fiction", "Self Help", "Fantasy", "Poetry"],
    "Lifestyle": ["Minimalism", "Travel", "Productivity", "Mindfulness", "Habits"],
    "Health": ["Nutrition", "Mental Health", "Workout", "Yoga", "Sleep"],
    "Food": ["Cooking", "Street Food", "Vegan", "Desserts", "Coffee"],
    "Politics": ["World Politics", "Indian Politics", "Policy", "Geopolitics", "Debates"],
    "Gaming": ["PC Gaming", "Console", "Esports", "Mobile Gaming", "Indie Games"],
    "Fashion": ["Streetwear", "Luxury", "Minimal", "Vintage", "Sneakers"],
  };

  final Set<String> selectedInterests = {};
  final Set<String> expandedCategories = {};

  Future<void> createAccount() async {
    if (selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one interest")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? profileImageUrl;
      String uid = "";

      // Check if we are already logged in (Google Signup) or if we need to create an account
      User? currentUser = AuthService.instance.currentUser;
      
      if (currentUser != null && currentUser.email == widget.email) {
        // We are already logged in (Google)
        uid = currentUser.uid;

        // Link with Email/Password so they can use the Login button too!
        try {
          AuthCredential credential = EmailAuthProvider.credential(
              email: widget.email, password: widget.password);
          await currentUser.linkWithCredential(credential);
        } catch (e) {
          debugPrint("Note: Account already linked or error: $e");
          // If already linked, or error, we still proceed to save the profile
        }
      } else {
        // Email/Password Signup - Create Auth User first
        UserCredential userCredential = await AuthService.instance
            .createUserWithEmailAndPassword(
                email: widget.email, password: widget.password);
        uid = userCredential.user!.uid;
      }

      // 2. Upload Image to Storage (if selected)
      if (widget.profileImage != null) {
        profileImageUrl = await StorageService.instance.uploadProfilePicture(
          userId: uid,
          file: widget.profileImage!,
        );
      }

      // 3. Save Profile to Firestore
      await DatabaseService.instance.createUserProfile(
        uid: uid,
        email: widget.email,
        username: widget.username,
        fullName: widget.fullName,
        bio: widget.bio,
        profileImageUrl: profileImageUrl ?? "",
        interests: selectedInterests.toList(),
      );

      if (mounted) {
        await CurrentUserService.instance.loadCurrentUser();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_registered', true);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void goLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
              Text(
                "Select topics to personalize your experience.",
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white54 : Colors.black54,
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
              GestureDetector(
                onTap: isLoading ? null : () { KnockHaptics.tap(); createAccount(); },
                child: Container(
                  height: 58,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: KnockPostLoadingIndicator(
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : Text(
                            "Continue",
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: GestureDetector(
                  onTap: () { KnockHaptics.tap(); goLogin(); },
                  child: Text(
                    "Already have an account? Log in",
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white54 : Colors.black54,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isSelected = selectedInterests.contains(label);
    return GestureDetector(
      onTap: () {
        KnockHaptics.selection();
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
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected || expandedCategories.contains(label)
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
