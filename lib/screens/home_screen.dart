import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text(
              "Knockpost",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Home Screen",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                // later logout logic
              },
              child: const Text("Logout"),
            )

          ],
        ),
      ),
    );
  }
}
