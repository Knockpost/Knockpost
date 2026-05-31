import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalAgreementText extends StatelessWidget {
  const LegalAgreementText({super.key});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(
        url,
        mode: LaunchMode.inAppBrowserView,
      );
    } catch (e) {
      debugPrint("Could not launch $urlString: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white54 : Colors.black54;
    final linkColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 10.5,
            height: 1.5,
            color: baseColor,
            fontFamily: 'Inter', // Assuming Inter based on styling
          ),
          children: [
            const TextSpan(text: 'By continuing, you agree to KnockPost’s '),
            TextSpan(
              text: 'Terms & Conditions',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: linkColor,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  _launchUrl('https://knockpost.com/terms');
                },
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: linkColor,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  _launchUrl('https://knockpost.com/privacy');
                },
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
