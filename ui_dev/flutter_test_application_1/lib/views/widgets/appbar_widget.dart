import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/constants.dart';
import '../../data/notifiers.dart';

class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppbarWidget({super.key});

  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://www.plantphenomics.org.au/');
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.green,
      title: const Text("Plant Disease Detector"),
      centerTitle: true
    );
  }


  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
