import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'interest_selection_screen.dart';
import '../login_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  final bool isGoogleSignup;

  const ProfileSetupScreen({
    super.key,
    required this.email,
    required this.username,
    required this.password,
    this.isGoogleSignup = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {

  final TextEditingController nameController = TextEditingController();

  File? selectedImage;
  DateTime? selectedDate;

  final ImagePicker picker = ImagePicker();

  // 🔥 IMAGE PICKER
  Future<void> pickImage() async {
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  // 🔥 CUSTOM DATE PICKER (SHORT MONTH VERSION)
  void pickDate() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {

        DateTime tempPickedDate =
            selectedDate ?? DateTime(2000, 1, 1);

        return SizedBox(
          height: 320 + MediaQuery.of(context).viewPadding.bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
            child: Column(
              children: [

                const SizedBox(height: 16),

              // Top bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [

                    GestureDetector(
                      onTap: () =>
                          Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),

                    const Text(
                      "Select date",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = tempPickedDate;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Row(
                  children: [

                    // MONTH
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController:
                            FixedExtentScrollController(
                          initialItem:
                              (selectedDate?.month ?? 1) -
                                  1,
                        ),
                        selectionOverlay: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: Colors.black12),
                              bottom: BorderSide(
                                  color: Colors.black12),
                            ),
                          ),
                        ),
                        onSelectedItemChanged:
                            (index) {
                          tempPickedDate =
                              DateTime(
                            tempPickedDate.year,
                            index + 1,
                            tempPickedDate.day,
                          );
                        },
                        children: const [
                          Text("Jan"),
                          Text("Feb"),
                          Text("Mar"),
                          Text("Apr"),
                          Text("May"),
                          Text("Jun"),
                          Text("Jul"),
                          Text("Aug"),
                          Text("Sep"),
                          Text("Oct"),
                          Text("Nov"),
                          Text("Dec"),
                        ],
                      ),
                    ),

                    // DAY
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController:
                            FixedExtentScrollController(
                          initialItem:
                              (selectedDate?.day ?? 1) -
                                  1,
                        ),
                        selectionOverlay: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: Colors.black12),
                              bottom: BorderSide(
                                  color: Colors.black12),
                            ),
                          ),
                        ),
                        onSelectedItemChanged:
                            (index) {
                          tempPickedDate =
                              DateTime(
                            tempPickedDate.year,
                            tempPickedDate.month,
                            index + 1,
                          );
                        },
                        children: List.generate(
                          31,
                          (index) =>
                              Text("${index + 1}"),
                        ),
                      ),
                    ),

                    // YEAR
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController:
                            FixedExtentScrollController(
                          initialItem:
                              (selectedDate?.year ??
                                      2000) -
                                  1900,
                        ),
                        selectionOverlay: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: Colors.black12),
                              bottom: BorderSide(
                                  color: Colors.black12),
                            ),
                          ),
                        ),
                        onSelectedItemChanged:
                            (index) {
                          tempPickedDate =
                              DateTime(
                            1900 + index,
                            tempPickedDate.month,
                            tempPickedDate.day,
                          );
                        },
                        children: List.generate(
                          DateTime.now().year -
                              1899,
                          (index) => Text(
                              "${1900 + index}"),
                        ),
                      ),
                    ),

                  ],
                ),
              ),

            ],
          ),
          ),
        );
      },
    );
  }

  void goNext() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InterestSelectionScreen(
          email: widget.email,
          username: widget.username,
          password: widget.password,
          fullName: name,
          profileImage: selectedImage,
          isGoogleSignup: widget.isGoogleSignup,
        ),
      ),
    );
  }

  void goBack() {
    Navigator.pop(context);
  }

  void goLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String formatDate() {
    if (selectedDate == null) {
      return "Date of birth";
    }
    return "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            const SizedBox(height: 13),

            // 🔥 HEADER
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 20),
              child: Row(
                children: [

                  GestureDetector(
                    onTap: () { KnockHaptics.tap(); goBack(); },
                    child: Icon(
                      Icons.arrow_back,
                      size: 25,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),

                  const Spacer(),

                  Image.asset(
                    isDark ? "assets/icon(drak background).png" : "assets/icon(light backgroud).png",
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),

                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  30,
                  24,
                  MediaQuery.of(context)
                          .viewInsets
                          .bottom +
                      24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Set up your profile",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Add a photo and your details.",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // PROFILE IMAGE
                    Center(
                      child: Stack(
                        alignment:
                            Alignment.bottomRight,
                        children: [

                          GestureDetector(
                            onTap: () { KnockHaptics.tap(); pickImage(); },
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: isDark 
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF2F2F2),
                              backgroundImage:
                                  selectedImage !=
                                          null
                                      ? FileImage(
                                          selectedImage!)
                                      : null,
                              child:
                                  selectedImage ==
                                          null
                                      ? Icon(
                                          Icons
                                              .person,
                                          size: 50,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        )
                                      : null,
                            ),
                          ),

                          Positioned(
                            bottom: 0,
                            right: 4,
                            child: GestureDetector(
                              onTap: () { KnockHaptics.tap(); pickImage(); },
                              child: Container(
                                height: 32,
                                width: 32,
                                decoration:
                                    BoxDecoration(
                                  color: isDark ? Colors.white : Colors.black,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              20),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // NAME
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2),
                        borderRadius:
                            BorderRadius.circular(
                                16),
                      ),
                      child: TextField(
                        controller:
                            nameController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText:
                              "Full name",
                          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                          border:
                              InputBorder.none,
                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // DOB
                    GestureDetector(
                      onTap: () { KnockHaptics.tap(); pickDate(); },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2),
                          borderRadius:
                              BorderRadius
                                  .circular(16),
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                                    horizontal:
                                        20,
                                    vertical:
                                        20),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [

                            Text(
                              formatDate(),
                              style:
                                  TextStyle(
                                fontSize: 16,
                                color:
                                    selectedDate ==
                                            null
                                        ? (isDark ? Colors.white54 : Colors.black45)
                                        : (isDark ? Colors.white : Colors.black),
                              ),
                            ),

                            Icon(
                              Icons
                                  .calendar_today,
                              size: 18,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),

                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // NEXT
                    GestureDetector(
                      onTap: () { KnockHaptics.tap(); goNext(); },
                      child: Container(
                        height: 58,
                        width:
                            double.infinity,
                        decoration:
                            BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius:
                              BorderRadius
                                  .circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Next",
                            style:
                                TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 17,
                              fontWeight:
                                  FontWeight
                                      .w600,
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

          ],
        ),
      ),
    );
  }
}
