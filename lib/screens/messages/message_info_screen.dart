import 'package:flutter/material.dart';

class MessageInfoScreen extends StatelessWidget {
  const MessageInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final cardColor = isDark ? const Color(0xff1C1C1E) : const Color(0xfff5f7fb);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Chat Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),

            /// USER PROFILE
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A7CFF).withOpacity(0.3), width: 3),
                ),
                child: const CircleAvatar(
                  radius: 60,
                  backgroundImage: AssetImage("assets/test1.jpg"),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "Emma Brown",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            
            const SizedBox(height: 6),
            
            Text(
              "@emma_b",
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 40),

            /// OPTIONS CONTAINER
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildOption(
                    icon: Icons.notifications_off_outlined,
                    text: "Mute Notifications",
                    textColor: textColor,
                  ),
                  _buildDivider(isDark),
                  _buildOption(
                    icon: Icons.photo_outlined, 
                    text: "Shared Media",
                    textColor: textColor,
                  ),
                  _buildDivider(isDark),
                  _buildOption(
                    icon: Icons.search_rounded, 
                    text: "Search in Chat",
                    textColor: textColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// DANGER OPTIONS CONTAINER
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildOption(
                    icon: Icons.block,
                    text: "Block User",
                    textColor: Colors.redAccent,
                  ),
                  _buildDivider(isDark),
                  _buildOption(
                    icon: Icons.report_outlined,
                    text: "Report User",
                    textColor: Colors.redAccent,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1, 
      thickness: 0.5, 
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      indent: 56, // Align with text
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String text,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500, size: 20),
          ],
        ),
      ),
    );
  }
}
