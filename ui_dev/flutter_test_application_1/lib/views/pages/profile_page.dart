import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FractionallySizedBox(
                widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                child: Column(
                  spacing: 20.0,
                  children: [
                    CircleAvatar(
                      radius: 50.0,
                      backgroundImage: AssetImage(
                        'assets/images/background.jpg',
                      ),
                    ),
                    Text("Profile Page"),
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        child: Padding(padding: EdgeInsets.all(50.0)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
