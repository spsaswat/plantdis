import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http_parser/http_parser.dart'; // Import for supporting contentType

/// This is a Flutter StatefulWidget that implements a page for
/// selecting an image from the gallery, preprocessing it, sending it
/// to a Flask server for segmentation, and displaying the result.
class SamModelPage extends StatefulWidget {
  @override
  _SamModelPageState createState() => _SamModelPageState();
}

class _SamModelPageState extends State<SamModelPage> {
  Uint8List? _imageData; // Stores the selected or processed image data
  Uint8List? _maskImage; // Stores the result of the segmented image
  bool _isModelLoaded = true; // Tracks the model's loading state

  // URL to your Flask server for image segmentation
  String serverUrl = 'http://192.168.10.216:5000/predict';

  @override
  void initState() {
    super.initState();
    // Initialize EasyLoading configuration
    EasyLoading.instance
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..maskType = EasyLoadingMaskType.black
      ..userInteractions = false; // Disables user interaction during loading
  }

  /// This method allows the user to select an image from the gallery.
  /// After an image is selected, it is resized to 640x640 pixels before
  /// being displayed and used for segmentation.
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final Uint8List imageData = await image.readAsBytes();

      // Preprocess the image: resize to 640x640
      final Uint8List resizedImageData = _preprocessImage(imageData);

      setState(() {
        _imageData = resizedImageData; // Update the UI with the resized image
        _maskImage = null; // Reset the mask image
      });

      print('Image picked and resized');
    }
  }

  /// Preprocesses the selected image by resizing it to 640x640 pixels.
  /// It uses the `image` package to decode and resize the image, then
  /// encodes it back into a Uint8List format.
  ///
  /// - [imageData]: The original image data from the gallery.
  /// - Returns a Uint8List of the resized image.
  Uint8List _preprocessImage(Uint8List imageData) {
    // Decode the image data into an img.Image object
    img.Image? image = img.decodeImage(imageData);

    // Resize the image to 640x640 pixels
    img.Image resizedImage = img.copyResize(image!, width: 640, height: 640);

    // Encode the resized image into a PNG format and return as Uint8List
    return Uint8List.fromList(img.encodePng(resizedImage));
  }

  /// Sends the preprocessed image to the server for segmentation.
  /// This method sends an HTTP POST request with the image data to the
  /// Flask server. It also handles showing the loading indicator and
  /// displaying any error or success messages using `Fluttertoast`.
  Future<void> _runModel() async {
    if (_imageData == null) {
      // Show a message if no image is selected
      Fluttertoast.showToast(msg: 'Please select an image first.');
      return;
    }

    try {
      // Show the EasyLoading indicator while the request is being processed
      EasyLoading.show(status: 'Processing...');

      print('Sending image for segmentation...');

      // Prepare the image data for the POST request
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(http.MultipartFile.fromBytes(
        'file', // Field name in the request
        _imageData!, // Image data to be sent
        filename: 'image.jpg', // Filename to identify the image
        contentType: MediaType('image', 'jpeg'), // Set the content type to JPEG
      ));

      // Send the POST request to the server
      var response = await request.send();

      // Check if the response from the server is successful
      if (response.statusCode == 200) {
        // Parse the response data
        var responseData = await http.Response.fromStream(response);
        var jsonResponse = jsonDecode(responseData.body);

        // The server returns the segmented image as a base64 string
        String base64Image = jsonResponse['image'];
        setState(() {
          // Decode the base64 string into an image and update the UI
          _maskImage = base64Decode(base64Image);
        });

        print('Segmentation completed and image received');

        // Show a success message using Fluttertoast
        Fluttertoast.showToast(msg: 'Segmentation Complete');
      } else {
        // Handle unsuccessful response
        print('Failed to get response from the server');
        Fluttertoast.showToast(msg: 'Segmentation Failed');
      }
    } catch (e) {
      // Handle any errors that occur during the request
      print('Error running model: $e');
      Fluttertoast.showToast(msg: 'Error: ${e.toString()}');
    } finally {
      // Hide the EasyLoading indicator when the request is complete
      EasyLoading.dismiss();
    }
  }

  /// Builds the UI for the SamModelPage. It includes a layout for selecting
  /// an image, running segmentation, and displaying both the original and
  /// segmented images.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SAM Model Segmentation'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // If segmentation is complete, display the segmented image
            _maskImage != null
                ? Container(
              margin: const EdgeInsets.all(20.0),
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                children: [
                  Text(
                    'Segmented Image',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  // Display the segmented image
                  Image.memory(
                    _maskImage!,
                    fit: BoxFit.cover,
                  ),
                ],
              ),
            )
                : Container(),

            // Instruction to choose the plant to analyze
            Container(
              margin: const EdgeInsets.fromLTRB(0, 20, 0, 10),
              child: const Center(
                child: Text(
                  'Please choose the plant you want to analyse first',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Display the selected image (if available)
            _imageData == null
                ? Text('No image selected.')
                : Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Image.memory(
                _imageData!,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 20),

            // Button to pick an image from the gallery
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 10),

            // Button to run segmentation on the selected image
            ElevatedButton(
              onPressed: _isModelLoaded ? _runModel : null,
              child: Text('Run Segmentation'),
            ),
          ],
        ),
      ),
    );
  }
}
