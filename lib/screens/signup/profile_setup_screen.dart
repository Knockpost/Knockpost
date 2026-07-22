import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'interest_selection_screen.dart';
import '../login_screen.dart';
import '../../services/auth_service.dart';

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
  final TextEditingController bioController = TextEditingController();
  bool _showErrors = false;

  File? selectedImage;
  DateTime? selectedDate;

  final ImagePicker picker = ImagePicker();

  // 🔥 IMAGE PICKER
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: Colors.white,
          dimmedLayerColor: Colors.black.withValues(alpha: 0.8),
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white24,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Profile Photo',
          aspectRatioLockEnabled: true,
          resetButtonHidden: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        selectedImage = File(croppedFile.path);
      });
    }
  }

  void _showImageSourceBottomSheet() {
    KnockHaptics.selection();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: textColor),
                title: Text(
                  'Choose from library',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: textColor),
                title: Text(
                  'Take photo',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (selectedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remove current picture',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      selectedImage = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 CUSTOM DATE PICKER (SHORT MONTH VERSION)
  void pickDate() {
    FocusManager.instance.primaryFocus?.unfocus(); // Dismiss keyboard
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
                        fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w700,
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
    final bio = bioController.text.trim();
    
    if (name.isEmpty || bio.isEmpty || selectedDate == null) {
      setState(() {
        _showErrors = true;
      });
      KnockHaptics.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all the mandatory fields")),
      );
      return;
    }

    final today = DateTime.now();
    int age = today.year - selectedDate!.year;
    if (today.month < selectedDate!.month ||
        (today.month == selectedDate!.month && today.day < selectedDate!.day)) {
      age--;
    }

    if (age <= 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be at least 13 years old to use this app.")),
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
          bio: bio,
          profileImage: selectedImage,
          isGoogleSignup: widget.isGoogleSignup,
        ),
      ),
    );
  }

  void goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      AuthService.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
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
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
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
                            onTap: () { KnockHaptics.tap(); _showImageSourceBottomSheet(); },
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
                              onTap: () { KnockHaptics.tap(); _showImageSourceBottomSheet(); },
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _showErrors && nameController.text.trim().isEmpty 
                              ? Colors.red 
                              : Colors.transparent,
                          width: 1.5,
                        ),
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

                    // BIO
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _showErrors && bioController.text.trim().isEmpty 
                              ? Colors.red 
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: bioController,
                        maxLines: 3,
                        minLines: 1,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: "Bio",
                          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showErrors && selectedDate == null
                                ? Colors.red 
                                : Colors.transparent,
                            width: 1.5,
                          ),
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
      ),
    );
  }
}
