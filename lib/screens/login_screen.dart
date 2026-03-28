import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup/signup_email_screen.dart';
import 'signup/signup_username_screen.dart';
import 'signup/signup_verification_screen.dart';
import 'home_screen.dart';

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

    
  }

  @override
  Widget build(BuildContext context) {

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputFillColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xfff2f2f2);
    final hintColor = isDark ? Colors.white54 : Colors.black54;
    final buttonBgColor = isDark ? Colors.white : Colors.black;
    final buttonTextColor = isDark ? Colors.black : Colors.white;
    final iconName = isDark ? "assets/splash_icon_dark.png" : "assets/icon(white).png";
    final dividerColor = isDark ? Colors.white24 : Colors.black26;

    return Scaffold(
      backgroundColor: bgColor,

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
                          iconName,
                          width: 70,
                          height: 70,
                        ),

                        const SizedBox(height: 14),

                        Text(
                          "Only You Matters",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: hintColor,
                            letterSpacing: 0.4,
                          ),
                        ),

                        const SizedBox(height: 48),

                        /// USERNAME
                        TextField(
                          controller: userController,

                          decoration: InputDecoration(
                            hintText: "Email",

                            filled: true,
                            fillColor: inputFillColor,

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
                            fillColor: inputFillColor,

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
                                color: hintColor,
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
                              backgroundColor: buttonBgColor,
                              elevation: 0,
                              shadowColor: Colors.transparent,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            onPressed: isLoading ? null : login,

                            child: isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: buttonTextColor,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Log in",
                                    style: TextStyle(
                                      color: buttonTextColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        /// DIVIDER
                        Row(
                          children: [

                            const Expanded(child: Divider()),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                "OR",
                                style: TextStyle(color: hintColor),
                              ),
                            ),

                            const Expanded(child: Divider()),

                          ],
                        ),

                        const SizedBox(height: 22),

                        /// GOOGLE BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 54,

                          child: OutlinedButton(

                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: dividerColor),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            onPressed: isLoading ? null : signInWithGoogle,

                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [

                                Image.asset(
                                  "assets/google.png",
                                  width: 22,
                                ),

                                const SizedBox(width: 10),

                                Text(
                                  "Continue with Google",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textColor,
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
                          child: Text(
                            "Don't have an account? Sign up",
                            style: TextStyle(
                              color: hintColor,
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
    final email = userController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both email and password")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          if (!user.emailVerified) {
            // For regular email/password login, unverified users MUST verify first
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SignupVerificationScreen(
                  email: user.email ?? "",
                ),
              ),
            );
            return;
          }

          if (userDoc.exists) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => SignupUsernameScreen(
                  email: user.email ?? "",
                  isGoogleSignup: true,
                ),
              ),
              (route) => false,
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Login Error: ${e.code} - ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed")),
        );
      }
    } catch (e) {
      debugPrint("Generic Login Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
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

  Future<void> signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1. Configure with Web Client ID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '56941114478-99oi3tmack3hmtelf5l0vp6j4oe8hson.apps.googleusercontent.com',
      );
      
      await googleSignIn.signOut().catchError((_) => null);

      // 2. Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        setState(() {
          isLoading = false;
        });
        return;
      }

      // 3. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 4. Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Once signed in, return the UserCredential
      await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          // Google users are pre-verified, so we skip SignupVerificationScreen entirely
          if (userDoc.exists) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            // New Google user -> Pick a username first
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => SignupUsernameScreen(
                  email: user.email ?? "",
                  isGoogleSignup: true,
                ),
              ),
              (route) => false,
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Login Error: ${e.code} - ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed")),
        );
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google Sign-In failed: $e")),
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
}
