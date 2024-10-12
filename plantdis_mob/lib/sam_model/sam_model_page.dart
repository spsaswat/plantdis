import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http_parser/http_parser.dart'; // 添加此包以支持 contentType

class SamModelPage extends StatefulWidget {
  @override
  _SamModelPageState createState() => _SamModelPageState();
}

class _SamModelPageState extends State<SamModelPage> {
  Uint8List? _imageData;
  Uint8List? _maskImage;
  bool _isModelLoaded = true;

  // 更新服务器URL为您的Docker IP和端口
  String serverUrl = 'http://192.168.10.216:5000/predict';

  @override
  void initState() {
    super.initState();
    // 初始化 EasyLoading 配置
    EasyLoading.instance
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..maskType = EasyLoadingMaskType.black
      ..userInteractions = false;
  }

  // 从图库选择图片并进行预处理
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final Uint8List imageData = await image.readAsBytes();

      // 预处理图片 (调整大小为 640x640)
      final Uint8List resizedImageData = _preprocessImage(imageData);

      setState(() {
        _imageData = resizedImageData; // 显示调整后的图片
        _maskImage = null; // 重置分割图片
      });

      print('Image picked and resized');
    }
  }

  // 预处理图片（调整大小为 640x640）
  Uint8List _preprocessImage(Uint8List imageData) {
    // 将图片数据解码为 img.Image
    img.Image? image = img.decodeImage(imageData);

    // 调整大小为 640x640
    img.Image resizedImage = img.copyResize(image!, width: 640, height: 640);

    // 将调整大小后的图像编码为 PNG 格式
    return Uint8List.fromList(img.encodePng(resizedImage));
  }

  // 发送图片到服务器进行分割
  Future<void> _runModel() async {
    if (_imageData == null) {
      Fluttertoast.showToast(msg: 'Please select an image first.');
      return;
    }

    try {
      // 显示加载指示器
      EasyLoading.show(status: 'Processing...');

      print('Sending image for segmentation...');

      // 准备图片数据
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _imageData!,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      // 发送请求到服务器
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await http.Response.fromStream(response);
        var jsonResponse = jsonDecode(responseData.body);

        // 服务器返回的分割图像为base64字符串
        String base64Image = jsonResponse['image'];
        setState(() {
          _maskImage = base64Decode(base64Image); // 解码并显示分割图像
        });

        print('Segmentation completed and image received');

        // 显示完成的Toast
        Fluttertoast.showToast(msg: 'Segmentation Complete');
      } else {
        print('Failed to get response from the server');
        Fluttertoast.showToast(msg: 'Segmentation Failed');
      }
    } catch (e) {
      print('Error running model: $e');
      Fluttertoast.showToast(msg: 'Error: ${e.toString()}');
    } finally {
      // 隐藏加载指示器
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SAM Model Segmentation'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 显示分割后的图片（子窗口）
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
                  Image.memory(
                    _maskImage!,
                    fit: BoxFit.cover,
                  ),
                ],
              ),
            )
                : Container(),
            // 提示文本，确保居中显示
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
            // 显示选中的图片
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
            // 选择图片按钮
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 10),
            // 运行分割按钮
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
