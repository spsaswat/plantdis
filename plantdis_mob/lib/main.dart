import 'dart:async';
import 'dart:typed_data';
import 'package:PlantDis/setting_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'CropCassavaModel.dart';
import 'login_page.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'plant_village.dart';
import 'result_page.dart';
import 'sam_model/sam_model_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasData) {
          print('User is signed in');
          return MyAppHome(userId: '');

        } else {
          return MyAppHome(userId: '');
        }
      },
    );
  }
}

class MyAppHome extends StatefulWidget {
  final String userId;
  MyAppHome({required this.userId});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyAppHome> {
  bool isDarkMode = false;

  Future<void> _saveResultToFirestore(File imageFile, String result, String feedback) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userId = user.uid;
      try {
        final storageRef = FirebaseStorage.instance.ref().child('images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = storageRef.putFile(imageFile);

        await uploadTask;

        final imageUrl = await storageRef.getDownloadURL();
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

        final docSnapshot = await userDocRef.get();
        if (!docSnapshot.exists) {
          await userDocRef.set({
            'results': [],
            'images': []
          });
        }

        await userDocRef.update({
          'results': FieldValue.arrayUnion([{
            'result': result,
            'feedback': feedback,
            'image': imageUrl,
          }]),
        });

        print('Result, feedback, and image saved to Firestore successfully');
      } catch (e) {
        print('Failed to save result, feedback, and image to Firestore: $e');
      }
    } else {
      print('No user signed in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.green[600],
        scaffoldBackgroundColor: Colors.lightGreenAccent,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.green[600],
        scaffoldBackgroundColor: Colors.black,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PlantDis'),
          backgroundColor: Colors.green[600],
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.settings),
                onPressed: () async {
                  final settings = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(
                        isTtsOn: MyImagePickerStateTTS.isTtsOn,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  );
                  if (settings != null) {
                    setState(() {
                      MyImagePickerStateTTS.isTtsOn = settings['isTtsOn'];
                      isDarkMode = settings['isDarkMode'];
                    });
                  }
                },
              ),
            ),
          ],
        ),
        body: Center(child: MyImagePicker(
          diagnoseLeafAndSave: _saveResultToFirestore,
        )),
      ),
      builder: EasyLoading.init(),
    );
  }
}

class MyImagePicker extends StatefulWidget {
  final Future<void> Function(File, String, String) diagnoseLeafAndSave;

  MyImagePicker({required this.diagnoseLeafAndSave});

  @override
  MyImagePickerState createState() => MyImagePickerState();
}

class MyImagePickerState extends State<MyImagePicker> {
  var _image;
  var path_1;
  var result;
  String selectedPlant = 'Cassava';
  List<String> plants = ['Cassava', 'Other plants'];
  CropCassavaModel? cropCassavaModel;
  PlantVillageModel? plantVillageModel;
  bool isCropModelLoaded = false;
  bool isPlantModelLoaded = false;

  @override
  void initState(){
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      if (selectedPlant == 'Cassava') {
        cropCassavaModel = CropCassavaModel();
        await cropCassavaModel!.loadModel();
        print('Crop Model loaded successfully');
        isCropModelLoaded = true;
      } else {
        plantVillageModel = PlantVillageModel();
        await plantVillageModel!.loadModel();
        print('Plant Village Model loaded successfully');
        isPlantModelLoaded = true;
      }
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future imageFromCamera() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    setState(() {
      if (image != null) {
        _image = File(image.path);
        path_1 = image.path;
      }
    });
  }

  Future imageFromGallery() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (image != null) {
        _image = File(image.path);
        path_1 = image.path;
      }
    });
  }

  Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Future<String> diagnoseLeaf() async {
    String diagnosisResult = "";
    double confidence = 0.0; // Initialize confidence with a default value

    if (path_1 != null) {
      EasyLoading.instance
        ..indicatorType = EasyLoadingIndicatorType.fadingGrid
        ..indicatorSize = 35.0
        ..radius = 6.0
        ..userInteractions = false
        ..dismissOnTap = false;

      EasyLoading.show(status: 'loading...');

      String rawResult;


      if (selectedPlant == 'Cassava') {
        if (!isCropModelLoaded) {
          await loadModel();
        }
        var cropOutput = await cropCassavaModel!.runModelOnImage(path_1);
        rawResult = cropOutput![0].toString();
        confidence = cropOutput[1];
        result = cropCassavaModel!.reformatResult(rawResult, confidence);
      } else {
        if (!isPlantModelLoaded) {
          await loadModel();
        }
        var output = await plantVillageModel!.runModelOnImage(path_1);

        if (output == null || output.isEmpty) {
          EasyLoading.dismiss();
          return 'Sorry! I could not identify anything';
        }

        rawResult = output[0].toString();
        result = plantVillageModel!.reformatResult(rawResult);
      }

      EasyLoading.dismiss();

      setState(() {
        diagnosisResult = result;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(
            image: _image,
            result: diagnosisResult,
            saveResultToFirestore: widget.diagnoseLeafAndSave,
          ),
        ),
      );
    } else {
      EasyLoading.instance
        ..displayDuration = const Duration(milliseconds: 2000)
        ..userInteractions = false
        ..dismissOnTap = true;
      EasyLoading.showToast('Please select or capture image');
    }

    return diagnosisResult;
  }

  void _showResultDialog(String result) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Result', style: TextStyle(color: Colors.black)),
          content: Text(result, style: TextStyle(color: Colors.black)),
          backgroundColor: const Color(0xffF8DC27),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(
      foregroundColor: const Color(0xff000000),
      backgroundColor: const Color(0xffF8DC27),
      shadowColor: const Color(0xffF8DC27).withOpacity(0.4),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.fromLTRB(0, 20, 0, 10),
                child: const Center(  // 使用 Center 小部件确保居中
                  child: Text(
                    'Please choose the plant you want to analyse first',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,  // 确保文本在容器内部居中对齐
                  ),
                ),
              ),

              Container(
                margin: const EdgeInsets.fromLTRB(0, 10, 0, 20),
                child: DropdownButton<String>(
                  value: selectedPlant,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedPlant = newValue!;
                      isCropModelLoaded = false;
                      isPlantModelLoaded = false;
                      loadModel();
                    });
                  },
                  items: plants.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                ),
              ),
              _image == null
                  ? const Text('No image selected.')
                  : Image.file(_image,
                  width: 300, height: 200, fit: BoxFit.cover),
              Container(
                margin: const EdgeInsets.fromLTRB(0, 30, 0, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      color: const Color(0xffF8DC27),
                      onPressed: () => imageFromCamera(),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(Icons.collections),
                      color: const Color(0xffF8DC27),
                      onPressed: () => imageFromGallery(),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(0, 30, 0, 20),
                child: ElevatedButton(
                  onPressed: () async {
                    String result = await diagnoseLeaf(); // call the diagnose func to get the result string
                    // Pass empty feedback initially
                  },
                  child: const Text('Diagnose'),
                  style: style,
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(0, 30, 0, 20),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                    context,
                      MaterialPageRoute(builder: (context) => SamModelPage()), // Navigate to the new page
              );
            },
                  child: const Text('SAM Model'),
                  style: style,
          ),
        ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyImagePickerStateTTS extends State<MyImagePicker> {
  static bool isTtsOn = false;
  static final FlutterTts flutterTts = FlutterTts();

  static void updateResult(String result) {
    if (isTtsOn) {
      flutterTts.speak(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(); // Implement your widget tree here
  }
}