import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';

class SignupPasswordScreen extends StatefulWidget {
  const SignupPasswordScreen({super.key});

  @override
  State<SignupPasswordScreen> createState() =>
      _SignupPasswordScreenState();
}

class _SignupPasswordScreenState
    extends State<SignupPasswordScreen> {

  final TextEditingController passwordController =
      TextEditingController();

  bool isObscured = true;

  void goNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(),
      ),
    );
  }

  void goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            // 🔥 Same Premium Header
            const SizedBox(height: 13),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [

                  GestureDetector(
                    onTap: goBack,
                    child: const Icon(
                      Icons.arrow_back,
                      size: 25,
                      color: Colors.black,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    height: 33,
                    width: 33,
                    child: Image.asset(
                      "assets/icon(white).png",
                      fit: BoxFit.contain,
                    ),
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
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Create a password",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      "Make sure it's strong and secure.",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: passwordController,
                        obscureText: isObscured,
                        decoration: InputDecoration(
                          hintText: "Password",
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                isObscured = !isObscured;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: goNext,
                      child: Container(
                        height: 58,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: Text(
                            "Next",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
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