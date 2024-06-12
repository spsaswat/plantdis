import 'package:flutter/material.dart';
/// the switcher button use to open or off the tts mode,
/// tts on will make the @isTtsOn boolean to True
class SettingsPage extends StatefulWidget {
  final bool isTtsOn;

  const SettingsPage({required this.isTtsOn, required String result});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool isTtsOn;

  @override
  void initState() {
    super.initState();
    isTtsOn = widget.isTtsOn;
  }

  void _toggleTts(bool value) {
    setState(() {
      isTtsOn = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.record_voice_over, size: 100, color: Color(0xFF5F6368)),
            SizedBox(height: 20),
            Text('TTS Mode', style: TextStyle(fontSize: 20)),
            Switch(
              value: isTtsOn,
              onChanged: _toggleTts,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context, isTtsOn);
        },
        child: Icon(Icons.check),
      ),
    );
  }
}
