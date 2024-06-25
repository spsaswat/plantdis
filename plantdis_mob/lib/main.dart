import 'dart:async';
import 'dart:typed_data';
import 'package:PlantDis/register_page.dart';
import 'package:PlantDis/setting_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:segment_anything/segment_anything.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'login_server/Auth_service.dart';
import 'login_server/firebase_options.dart';
import 'login_server/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_storage/firebase_storage.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await Get.put(AuthService());
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),  // use authwrapper to check the email
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasData) {
          return MyAppHome();
        } else {
          return LoginPage();
        }
      },
    );
  }


class MyAppHome extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyAppHome> {
  bool isDarkMode = false;

  Future<void> _saveResultToFirestore(File imageFile, String result) async {
    final user = FirebaseAuth.instance.currentUser;
    String userId = user?.uid ?? "guest_user";
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putFile(imageFile);

      // Observe the state
      uploadTask.snapshotEvents.listen((TaskSnapshot taskSnapshot) {
        switch (taskSnapshot.state) {
          case TaskState.running:
            final progress = 100.0 * (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes);
            print("Upload is $progress% complete.");
            break;
          case TaskState.paused:
            print("Upload is paused.");
            break;
          case TaskState.canceled:
            print("Upload was canceled");
            break;
          case TaskState.error:
            print("Upload failed with error.");
            break;
          case TaskState.success:
            print("Upload completed successfully.");
            break;
        }
      });

      await uploadTask;

      final imageUrl = await storageRef.getDownloadURL();
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Check the doc
      final docSnapshot = await userDocRef.get();
      if (!docSnapshot.exists) {
        // Initiate doc if not exist
        await userDocRef.set({
          'results': [],
        });
      }

      // Create the new result entry
      Map<String, dynamic> newResult = {
        'imageUrl': imageUrl,
        'result': result,
      };

      // Update Firestore doc
      await userDocRef.update({
        'results': FieldValue.arrayUnion([newResult]),
      });

      print('Result and image saved to Firestore successfully');
    } catch (e) {
      print('Failed to save result and image to Firestore: $e');
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
                        isTtsOn: _MyImagePickerState.isTtsOn,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  );
                  if (settings != null) {
                    setState(() {
                      _MyImagePickerState.isTtsOn = settings['isTtsOn'];
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
  final Future<void> Function(File, String) diagnoseLeafAndSave;

  MyImagePicker({required this.diagnoseLeafAndSave});

  @override
  MyImagePickerState createState() => MyImagePickerState();
}

class MyImagePickerState extends State<MyImagePicker> {
  var _image;
  var path_1;
  var result;
  var segmentedResult;
  var segmentedMask;
  List<List<double>> inputPoints = [];
  Interpreter? interpreter;

  @override
  void initState(){
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async{
    try {
      interpreter = await Interpreter.fromAsset('assets/sam_model.tflite');
      print('SAM Model loaded successfully');
    } catch (e) {
      print('Error loading SAM model: $e');
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

  void showImageDialog(File image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Segment Image', style: TextStyle(color: Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(image, width: 300, height: 200, fit: BoxFit.cover),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                },
                child: const Text('Segment'),
              ),
            ],
          ),
          backgroundColor: const Color(0xffF8DC27),
          actions: [
            TextButton(
              child: Text('Close', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

    if (path_1 != null) {
      EasyLoading.instance
        ..indicatorType = EasyLoadingIndicatorType.fadingGrid
        ..indicatorSize = 35.0
        ..radius = 6.0
        ..userInteractions = false
        ..dismissOnTap = false;

      EasyLoading.show(status: 'loading...');

      await Tflite.loadModel(
          model: "assets/pd_tfl_dn_6.tflite", labels: "assets/labels.txt");

      var output = await Tflite.runModelOnImage(
        path: path_1,
        numResults: 1,
        threshold: 0.89,
        imageMean: 0,
        imageStd: 255,
      );

      EasyLoading.dismiss();

      setState(() {
        if (output != null && output.isNotEmpty) {
          String rawResult = output[0]['label'].toString();
          result = _reformatResult(rawResult);
          diagnosisResult = result;
        } else if (output != null && output.isEmpty) {
          result = 'Sorry! I could not identify anything';
          diagnosisResult = result;
        } else {
          result = "Sorry! My Model Failed";
          diagnosisResult = result;
        }
        _MyImagePickerState.updateResult(result);
        _showResultDialog(result);
      });
    } else {
      EasyLoading.instance
        ..displayDuration = const Duration(milliseconds: 2000)
        ..userInteractions = false
        ..dismissOnTap = true;
      EasyLoading.showToast('Please select or capture image');
    }

    return diagnosisResult; // return the result
  }

  String _reformatResult(String rawResult) {
    List<String> parts = rawResult.split('___');
    if (parts.length == 2) {
      String plant = parts[0];
      String disease = parts[1].replaceAll('_', ' ');
      if (disease == 'healthy'){
        return 'The plant is $plant, and it is healthy.';
      }else{
        return 'The plant is $plant, and the disease is $disease.';
      }}
    else {
      return rawResult; // return raw result if format is unexpected
    }
  }

  Future<void> segmentImage() async {
    if (_image == null) {
      EasyLoading.showToast('Please select or capture image');
      return;
    }

    var imageEmbedding = await Tflite.runModelOnImage(
      path: path_1,
      numResults: 1,
      threshold: 0.89,
      imageMean: 0,
      imageStd: 255,
    );

    // set the input point
    List<double> inputLabels = List.filled(inputPoints.length, 1.0);

    // add input points
    inputPoints.add([0.0, 0.0]);
    inputLabels.add(-1.0);

    // prepare the input infos
    var inputs = {
      "image_embeddings": imageEmbedding,
      "point_coords": [inputPoints],
      "point_labels": [inputLabels],
      "mask_input": List.filled(256 * 256, 0.0),
      "has_mask_input": [1.0],
      "orig_im_size": [256.0, 256.0]
    };

    // run the model
    List<double> outputMasks = List.filled(256 * 256, 0.0);
    interpreter!.run(inputs, outputMasks);

    // output mask
    var maskImage = await maskToImage(outputMasks);

    // save the img
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/segmented_image.png';
    File(imagePath).writeAsBytesSync(maskImage);
    setState(() {
      path_1 = imagePath;
    });
    EasyLoading.showToast('Image segmented successfully');
  }

  Future<Uint8List> maskToImage(List<double> mask) async {
    final int width = 256;
    final int height = 256;
    final img.Image image = img.Image(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * width + x;
        final int color = mask[index] > 0.5 ? 0xFFFFFFFF : 0xFF000000;
        image.setPixel(x, y, color);
      }
    }

    return Uint8List.fromList(img.encodePng(image));
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
                    await widget.diagnoseLeafAndSave(_image, result);

                  },
                  child: const Text('Diagnose'),
                  style: style,
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(0, 30, 0, 20),
                child: ElevatedButton(
                  onPressed: () => segmentImage(),
                  child: const Text('Segment Image'),
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

class _MyImagePickerState {
  static bool isTtsOn = false;
  static final FlutterTts flutterTts = FlutterTts();

  static void updateResult(String result) {
    if (isTtsOn) {
      flutterTts.speak(result);
    }
  }
}
