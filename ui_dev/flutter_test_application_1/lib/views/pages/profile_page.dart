import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:http/http.dart' as http;

import '../../data/classes/secret_class.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // late Secret secret;

  @override
  void initState() {
    getData();
    super.initState();
  }

  Future getData() async {
    var url = Uri.https('secrets-api.appbrewery.com', '/random');
    var response = await http.get(url);
    if (response.statusCode == 200) {
      return Secret.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      debugPrint("Request failed with status: ${response.statusCode}.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getData(),
      builder: (context, snapshot) {
        Widget widget;
        if (snapshot.connectionState == ConnectionState.waiting) {
          widget = Center(child: CircularProgressIndicator.adaptive());
        } else if (snapshot.hasData) {
          Secret secret = snapshot.data;
          widget = Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return FractionallySizedBox(
                      widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                      child: Column(
                        spacing: 15.0,
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
                              child: Padding(
                                padding: EdgeInsets.all(15.0),
                                child: Column(
                                  spacing: 5.0,
                                  children: [
                                    Text(
                                      "Secret",
                                      style: KTextStyle.titleTealText,
                                    ),
                                    Text(
                                      secret.secret,
                                      style: KTextStyle.descriptionText,
                                    ),
                                  ],
                                ),
                              ),
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
        } else {
          widget = Center(child: Text("Error"));
        }
        return widget;
      },
    );
  }
}
