import 'package:flutter/material.dart';

class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppbarWidget({super.key});

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
