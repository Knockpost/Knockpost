import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'signup/signup_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    // Lock system bars
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(

      backgroundColor: Colors.white,

      // IMPORTANT: disable resize
      resizeToAvoidBottomInset: false,

      body: SizedBox(
        height: screenHeight,
        width: screenWidth,

        child: Stack(
          children: [

            /// CENTER CONTENT (ABSOLUTE FIXED)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),

                    child: Column(
                      children: [

                        /// ICON
                        Image.asset(
                          "assets/icon(white).png",
                          width: 70,
                          height: 70,
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          "Only You Matters",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                            letterSpacing: 0.4,
                          ),
                        ),

                        const SizedBox(height: 48),

                        /// USERNAME
                        TextField(
                          controller: userController,

                          decoration: InputDecoration(
                            hintText: "Username or Email",

                            filled: true,
                            fillColor: const Color(0xfff2f2f2),

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// PASSWORD
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,

                          decoration: InputDecoration(
                            hintText: "Password",

                            filled: true,
                            fillColor: const Color(0xfff2f2f2),

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),

                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        /// LOGIN BUTTON (NO SHADOW)
                        SizedBox(
                          width: double.infinity,
                          height: 54,

                          child: ElevatedButton(

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              elevation: 0,
                              shadowColor: Colors.transparent,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            onPressed: login,

                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Log in",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        /// DIVIDER
                        const Row(
                          children: [

                            Expanded(child: Divider()),

                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                "OR",
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),

                            Expanded(child: Divider()),

                          ],
                        ),

                        const SizedBox(height: 22),

                        /// GOOGLE BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 54,

                          child: OutlinedButton(

                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black26),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            onPressed: () {},

                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [

                                Image.asset(
                                  "assets/google.png",
                                  width: 22,
                                ),

                                const SizedBox(width: 10),

                                const Text(
                                  "Continue with Google",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupEmailScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Don't have an account? Sign up",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      ],
                    ),
                  ),

                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  void login() async {

    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      isLoading = false;
    });
  }
}