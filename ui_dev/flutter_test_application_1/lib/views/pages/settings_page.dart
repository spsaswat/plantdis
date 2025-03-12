import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});

  final String title;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? isChecked = false;
  bool isSwitched = false;
  double sliderValue = 0.0;
  String? menuItem = "v1";

  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FractionallySizedBox(
                  widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 15,

                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        onEditingComplete: () => setState(() {}),
                      ),
                      Text(controller.text),

                      Divider(),

                      Checkbox(
                        value: isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            isChecked = value;
                          });
                        },
                      ),

                      CheckboxListTile.adaptive(
                        title: Text("Tile (Check Me!)"),
                        value: isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            isChecked = value;
                          });
                        },
                      ),

                      Switch(
                        value: isSwitched,
                        onChanged: (bool value) {
                          setState(() {
                            isSwitched = value;
                          });
                        },
                      ),
                      SwitchListTile.adaptive(
                        title: Text("Tile (Switch Me!)"),
                        value: isSwitched,
                        onChanged: (bool value) {
                          setState(() {
                            isSwitched = value;
                          });
                        },
                      ),
                      Slider(
                        value: sliderValue,
                        divisions: 20,
                        onChanged: (value) {
                          setState(() {
                            sliderValue = value;
                          });
                        },
                      ),
                      GestureDetector(
                        child: Image.asset('assets/images/background.jpg'),
                        onTap: () {
                          setState(() {
                            isSwitched = !isSwitched;
                          });
                        },
                        onDoubleTap: () {
                          setState(() {
                            isChecked = !isChecked!;
                          });
                        },
                      ),
                      FilledButton(
                        onPressed:
                            () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Snack bar Notification"),
                                duration: Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            ),
                        child: Text("Launch Snackbar"),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text("Alert Title"),
                                content: Text("Alert Content"),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text("Close"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Text("Launch Dialog window"),
                      ),

                      DropdownButton(
                        value: menuItem,
                        items: [
                          DropdownMenuItem(value: "v1", child: Text("Item 1")),
                          DropdownMenuItem(value: "v2", child: Text("Item 2")),
                          DropdownMenuItem(value: "v3", child: Text("Item 3")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            menuItem = value;
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
