import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
/// the switcher button use to open or off the tts mode,
/// tts on will make the @isTtsOn boolean to True
class SettingsPage extends StatefulWidget {
  final bool isTtsOn;
  final bool isDarkMode;

  SettingsPage({required this.isTtsOn, required this.isDarkMode, Key? key,})
      : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool isTtsOn;
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isTtsOn = widget.isTtsOn;
    isDarkMode = widget.isDarkMode;
  }

  void _toggleTts(bool value) {
    setState(() {
      isTtsOn = value;
    });
  }
  void _toggleDarkMode(bool value){
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green[600],
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 40), // the height of the 'tts mode'
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.record_voice_over, size: 80, color: Color(0xFF5F6368)),
                SizedBox(width: 40), // distance between icon, text and switch
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('TTS Mode', style: TextStyle(fontSize: 20)),
                    Switch(
                      value: isTtsOn,
                      onChanged: _toggleTts,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 80),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contrast, size: 80, color: Color(0xFF5F6368)),
                SizedBox(width: 40),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Dark Mode', style: TextStyle(fontSize: 20)),
                    Switch(value: isDarkMode, onChanged: _toggleDarkMode),
                  ],
                )

              ],
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context, {'isTtsOn': isTtsOn, 'isDarkMode':isDarkMode} );
        },
        child: Icon(Icons.check),
      ),
    );
  }


}
