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
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        onEditingComplete: () => setState(() {}),
                      ),
                      Text(controller.text),

                      const Divider(),

                      Checkbox(
                        value: isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            isChecked = value;
                          });
                        },
                      ),

                      CheckboxListTile.adaptive(
                        title: const Text("Tile (Check Me!)"),
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
                        title: const Text("Tile (Switch Me!)"),
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
                              const SnackBar(
                                content: Text("Snack bar Notification"),
                                duration: Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            ),
                        child: const Text("Launch Snackbar"),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Alert Title"),
                                content: const Text("Alert Content"),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Close"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text("Launch Dialog window"),
                      ),

                      DropdownButton(
                        value: menuItem,
                        items: const [
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
