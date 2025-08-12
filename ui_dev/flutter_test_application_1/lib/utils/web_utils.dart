import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebUtils {
  // This is now a static method, callable from anywhere in the app.
  // We pass BuildContext so it can show a SnackBar if needed.
  static Future<void> launchPlantDisWebsite(BuildContext context) async {
    final Uri url = Uri.parse('https://plantdis.github.io/');
    _launch(context, url);
  }

  static Future<void> launchAPPNWebsite(BuildContext context) async {
    final Uri url = Uri.parse('https://www.plantphenomics.org.au/');
    _launch(context, url);
  }

  // A private helper function to avoid code duplication within this class.
  static Future<void> _launch(BuildContext context, Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }
}
