// import 'dart:async';
// import 'dart:typed_data';
// import 'dart:ui' as ui;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:onnxruntime/onnxruntime.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;
//   ui.Image? image;

//   void _incrementCounter() {
//     // _inferSingleAdd();
//     // _inferMosaic9();
//     _inferSegLeaf();
//     setState(() {
//       _counter++;
//     });
//   }

//   // @override
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(widget.title),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Image.asset('assets/bluetit.jpg'),
//             RawImage(
//               image: image,
//             )
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Run ONNX model',
//         child: const Icon(Icons.play_arrow),
//       ),
//     );
//   }

//   void _inferSingleAdd() async {
//     OrtEnv.instance.init();
//     final sessionOptions = OrtSessionOptions();
//     final rawAssetFile = await rootBundle.load("assets/models/single_add.ort");
//     final bytes = rawAssetFile.buffer.asUint8List();
//     final session = OrtSession.fromBuffer(bytes, sessionOptions);
//     final runOptions = OrtRunOptions();
//     final inputOrt = OrtValueTensor.createTensorWithDataList(
//         Float32List.fromList([5.9]),
//     );
//     final inputs = {'A':inputOrt, 'B': inputOrt};
//     final outputs = session.run(runOptions, inputs);
//     inputOrt.release();
//     runOptions.release();
//     sessionOptions.release();
//     // session.release();
//     OrtEnv.instance.release();
//     List c = outputs[0]?.value as List;
//     print(c[0] ?? "none");
//   }

//   void _inferMosaic9() async {
//     OrtEnv.instance.init();
//     final sessionOptions = OrtSessionOptions();
//     // You can also try pointilism-9.ort and rain-princess.ort
//     final rawAssetFile = await rootBundle.load("assets/models/mosaic-9.ort");
//     final bytes = rawAssetFile.buffer.asUint8List();
//     final session = OrtSession.fromBuffer(bytes, sessionOptions);
//     final runOptions = OrtRunOptions();

//     // You can also try red.png, redgreen.png, redgreenblueblack.png for easy debug
//     ByteData blissBytes = await rootBundle.load('assets/bluetit.jpg');
//     final image = await decodeImageFromList(Uint8List.sublistView(blissBytes));
//     final rgbFloats = await imageToFloatTensor(image);
//     final inputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(rgbFloats), [1, 3, 224, 224]);

//     final inputs = {'input1':inputOrt};
//     final outputs = session.run(runOptions, inputs);
//     inputOrt.release();
//     runOptions.release();
//     sessionOptions.release();
//     // session.release();
//     OrtEnv.instance.release();
//     List outFloats = outputs[0]?.value as List;
//     print(outFloats[0] ?? "none");

//     final result = await floatTensorToImage(outFloats);
//     setState(() {
//       this.image = result;
//     });
//   }

//   // Future<List<double>> imageToFloatTensor(ui.Image image) async {
//   //   final imageAsFloatBytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
//   //   final rgbaUints = Uint8List.view(imageAsFloatBytes.buffer);

//   //   final indexed = rgbaUints.indexed;
//   //   return [
//   //   ...indexed.where((e) => e.$1 % 4 == 0).map((e) => e.$2.toDouble()),
//   //   ...indexed.where((e) => e.$1 % 4 == 1).map((e) => e.$2.toDouble()),
//   //   ...indexed.where((e) => e.$1 % 4 == 2).map((e) => e.$2.toDouble()),
//   //   ];
//   // }
//   Future<List<double>> imageToFloatTensor(ui.Image img) async {
//     final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
//     final rgba = Uint8List.view(bd!.buffer);
//     final r = <double>[], g = <double>[], b = <double>[];
//     for (int i = 0; i < rgba.length; i += 4) {
//       r.add(rgba[i]   / 255.0);
//       g.add(rgba[i+1] / 255.0);
//       b.add(rgba[i+2] / 255.0);
//     }
//     return [...r, ...g, ...b];
//   }

//   Future<ui.Image> floatTensorToImage(List tensorData) {
//     final outRgbaFloats = Uint8List(4 * 224 * 224);
//     for (int x = 0; x < 224; x++) {
//       for (int y = 0; y < 224; y++) {
//         final index = x * 224 * 4 + y * 4;
//         outRgbaFloats[index + 0] = tensorData[0][0][x][y].clamp(0, 255).toInt(); // r
//         outRgbaFloats[index + 1] = tensorData[0][1][x][y].clamp(0, 255).toInt(); // g
//         outRgbaFloats[index + 2] = tensorData[0][2][x][y].clamp(0, 255).toInt(); // b
//         outRgbaFloats[index + 3] = 255; // a
//       }
//     }
//     final completer = Completer<ui.Image>();
//     ui.decodeImageFromPixels(outRgbaFloats, 224, 224, ui.PixelFormat.rgba8888, (ui.Image image) {
//       completer.complete(image);
//     });

//     return completer.future;
//   }
//   // void _inferSegLeaf() async {
//   //   OrtEnv.instance.init();
//   //   final sessionOptions = OrtSessionOptions();
//   //   // 2. 加载你的 ONNX 分割模型
//   //   const assetFile = "assets/models/leaf_mask_rcnn.onnx";
//   //   final rawAssetFile = await rootBundle.load(assetFile);
//   //   final bytes = rawAssetFile.buffer.asUint8List();
//   //   final session = OrtSession.fromBuffer(bytes, sessionOptions);
//   //   final runOptions = OrtRunOptions();

//   //   // 3. 加载测试图片
//   //   final rawImage = await rootBundle.load('assets/leaf.jpg');
//   //   final ui.Image img = await decodeImageFromList(rawImage.buffer.asUint8List());
//   //   final int H = img.height, W = img.width;
//   //   print('Image size: ${img.width} x ${img.height}');
//   //   // 4. 预处理：转成 CHW 的 Float32List
//   //   final rgbFloats = await imageToFloatTensor(img);
//   //   final inputOrt = OrtValueTensor.createTensorWithDataList(
//   //     Float32List.fromList(rgbFloats),
//   //     [1, 3, H, W],
//   //   );
//   //   // 5. 运行推理
//   //   final outputs = session.run(runOptions, {'input': inputOrt});
//   //   // 6. 解析并打印每一个输出
//   //   //   idx 0: boxes [num_detections,4]
//   //   final List boxes = outputs[0]!.value as List;
//   //   print('>>> boxes (${boxes.length} detections): $boxes');
//   //   //   idx 1: labels [num_detections]
//   //   final List labels = outputs[1]!.value as List;
//   //   print('>>> labels: $labels');

//   //   //   idx 2: scores [num_detections]
//   //   final List scores = outputs[2]!.value as List;
//   //   print('>>> scores: $scores');

//   //   //   idx 3: masks [num_detections,1,H_mask,W_mask]
//   //   final List masks = outputs[3]!.value as List;
//   //   print('>>> masks dims: ${masks.length} detections, '
//   //         '${(masks.isNotEmpty ? (masks[0] as List).length : 0)} rows per mask');
//   //   // 7. 释放资源
//   //   inputOrt.release();
//   //   runOptions.release();
//   //   sessionOptions.release();
//   //   OrtEnv.instance.release();
//   // }
//   void _inferSegLeaf() async {
//     // 1. 初始化 ORT
//     OrtEnv.instance.init();
//     final so = OrtSessionOptions();

//     // 2. 加载模型
//     const modelAsset = 'assets/models/leaf_mask_rcnn.onnx';
//     final modelData = await rootBundle.load(modelAsset);
//     final session = OrtSession.fromBuffer(
//       modelData.buffer.asUint8List(), so);

//     // 打印 IO 名称
//     print('== ORT Session Inputs  ==  ${session.inputNames}');
//     print('== ORT Session Outputs ==  ${session.outputNames}');
//     final ro = OrtRunOptions();

//     // 3. 加载图片
//     const imageAsset = 'assets/leaf.jpg';
//     final imgData = await rootBundle.load(imageAsset);
//     final ui.Image img = await decodeImageFromList(
//       imgData.buffer.asUint8List());
//     final H = img.height, W = img.width;
//     print('Image size: ${W}×${H}');

//     // 4. 预处理
//     final floats = await imageToFloatTensor(img);
//     print('Normalized first-10 floats: ${floats.take(10).toList()}');
//     final inputOrt = OrtValueTensor.createTensorWithDataList(
//       Float32List.fromList(floats),
//       [1, 3, H, W],
//     );

//     // 5. 推理
//     final outputs = session.run(ro, {'input': inputOrt});

//     // 6. 解析并打印
//     final boxes  = (outputs[0]!.value as List).cast<List<double>>();
//     final labels = (outputs[1]!.value as List).cast<int>();
//     final scores = (outputs[2]!.value as List).cast<double>();
//     final masks  = outputs[3]!.value as List; // List of [1, H, W] per detection

//     print('>>> boxes (${boxes.length} detections): $boxes');
//     print('>>> labels: $labels');
//     print('>>> scores: $scores');

//     if (masks.isNotEmpty) {
//       // masks[0] 是长度 1 的 List，取第 0 个元素得到二维 mask
//       final mask2D = (masks[0] as List)[0] as List;      // List<List<double>>
//       final firstRow = (mask2D[0] as List).cast<double>(); // 第一行
//       // 阈值化并打印前 10 个值
//       final binRow = firstRow.map((v) => v > 0.5 ? 1 : 0).take(10).toList();
//       print('>>> binary mask first row (10 vals): $binRow');
//     }

//     // 7. 释放资源
//     inputOrt.release();
//     ro.release();
//     so.release();
//     OrtEnv.instance.release();
//   }
// }



import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leaf Segmentation Demo',
      theme: ThemeData(useMaterial3: true),
      home: const MyHomePage(title: 'Leaf Segmentation'),
    );
  }
}

class InferenceResult {
  final ui.Image image;
  final List<List<double>> boxes;
  final List<List<List<double>>> rawMasks; // [num, Hm, Wm]
  final List<double> scores;
  InferenceResult({
    required this.image,
    required this.boxes,
    required this.rawMasks,
    required this.scores,
  });
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  InferenceResult? result;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: result == null
            ? const Text('Press ▶ to run segmentation inference')
            : SizedBox(
                width: screenW,
                height: screenW * result!.image.height / result!.image.width,
                child: CustomPaint(
                  painter: SegPainter(result!),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _inferAndPaint,
        child: const Icon(Icons.play_arrow),
      ),
    );
  }

  Future<List<double>> imageToFloatTensor(ui.Image img) async {
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = Uint8List.view(bd!.buffer);
    final r = <double>[], g = <double>[], b = <double>[];
    for (int i = 0; i < rgba.length; i += 4) {
      r.add(rgba[i] / 255.0);
      g.add(rgba[i + 1] / 255.0);
      b.add(rgba[i + 2] / 255.0);
    }
    return [...r, ...g, ...b];
  }

  void _inferAndPaint() async {
    // 1. 初始化 ORT
    OrtEnv.instance.init();
    final so = OrtSessionOptions();
    final modelData = await rootBundle.load('assets/models/leaf_mask_rcnn.onnx');
    final session = OrtSession.fromBuffer(
      modelData.buffer.asUint8List(),
      so,
    );
    final ro = OrtRunOptions();

    // 2. 加载并解码图片
    final imgData = await rootBundle.load('assets/leaf3.jpg');
    final ui.Image imgRaw = await decodeImageFromList(
      imgData.buffer.asUint8List(),
    );
    final H = imgRaw.height, W = imgRaw.width;

    // 3. 预处理
    final floats = await imageToFloatTensor(imgRaw);
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(floats),
      [1, 3, H, W],
    );

    // 4. 推理
    final outputs = session.run(ro, {'input': inputOrt});
    final boxes = (outputs[0]!.value as List).cast<List<double>>();
    final scores = (outputs[2]!.value as List).cast<double>();
    final masks4D = outputs[3]!.value as List;
    // 转成 [num, Hm, Wm]
    final rawMasks = masks4D.map<List<List<double>>>((det) {
      final m2d = (det as List)[0] as List;
      return (m2d as List).cast<List<double>>();
    }).toList();

    for (int i = 0; i < rawMasks.length; i++) {
      final mask2d = rawMasks[i];
      final Hm = mask2d.length;               // 行数 = mask 的高度
      final Wm = mask2d.isNotEmpty
          ? (mask2d[0] as List).length        // 列数 = mask 的宽度
          : 0;
      print('Mask #$i shape: ${Hm}×${Wm}');
      // 如果还想检查阈值化后有多少正例：
      final posCount = mask2d
          .expand((row) => (row as List<double>))
          .where((v) => v > 0.5)
          .length;
      print('  Positive pixels: $posCount');
    }

    // 5. cleanup
    inputOrt.release();
    ro.release();
    so.release();
    OrtEnv.instance.release();

    // 6. 更新 state，触发绘制
    setState(() {
      result = InferenceResult(
        image: imgRaw,
        boxes: boxes,
        rawMasks: rawMasks,
        scores: scores,
      );
    });
  }
}

class SegPainter extends CustomPainter {
  final InferenceResult res;
  SegPainter(this.res);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 计算缩放比例并 apply
    final sx = size.width / res.image.width;
    final sy = size.height / res.image.height;
    canvas.save();
    canvas.scale(sx, sy);

    // 2. 画原图
    canvas.drawImage(res.image, Offset.zero, Paint());

    final paintBox = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / sx  // 线宽适应缩放
      ..color = Colors.greenAccent;
    final paintMask = Paint()
      ..style = PaintingStyle.fill
      ..color = const ui.Color.fromARGB(255, 58, 24, 197).withOpacity(0.8);

    // 3. 绘制每个检测 mask & 框
    for (int i = 0; i < res.boxes.length; i++) {
      final b = res.boxes[i];
      final score = res.scores[i];
      if (score < 0.5) continue;

      final x1 = b[0], y1 = b[1], x2 = b[2], y2 = b[3];
      final w = x2 - x1, h = y2 - y1;

      // 绘制 mask 小格
      final mask2D = res.rawMasks[i];
      final Hm = mask2D.length, Wm = mask2D[0].length;
      // final cellW = w / Wm, cellH = h / Hm;
      // for (int yy = 0; yy < Hm; yy++) {
      //   for (int xx = 0; xx < Wm; xx++) {
      //     if (mask2D[yy][xx] > 0.5) {
      //       final dx = x1 + xx * cellW;
      //       final dy = y1 + yy * cellH;
      //       canvas.drawRect(
      //         Rect.fromLTWH(dx, dy, cellW + 0.5, cellH + 0.5),
      //         paintMask,
      //       );
      //     }
      //   }
      // }
      final cellW = 1.0;  // 一个掩码像素对应原图(像素) 1:1
      final cellH = 1.0;

      for (int yy = 0; yy < Hm; yy++) {
        for (int xx = 0; xx < Wm; xx++) {
          if (mask2D[yy][xx] > 0.5) {
            // 这里 (xx,yy) 直接是原图坐标
            canvas.drawRect(
              Rect.fromLTWH(xx.toDouble(), yy.toDouble(), cellW, cellH),
              paintMask,
            );
          }
        }
      }

      // 绘制边框
      canvas.drawRect(Rect.fromLTWH(x1, y1, w, h), paintBox);

      // 绘制置信度
      final tp = TextPainter(
        text: TextSpan(
          text: '${(score * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14 / sx,
            shadows: [const Shadow(blurRadius: 2, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x1, y1 - tp.height));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// import 'dart:async';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'dart:io';
// import 'dart:convert';
// import 'package:path_provider/path_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:onnxruntime/onnxruntime.dart';

// void main() => runApp(const MyApp());

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) => MaterialApp(
//         title: 'Leaf Segmentation Demo',
//         theme: ThemeData(useMaterial3: true),
//         home: const MyHomePage(title: 'Leaf Segmentation'),
//       );
// }

// class InferenceResult {
//   final ui.Image image;
//   final List<List<double>> boxes;
//   final List<ui.Image> maskImages;
//   final List<double> scores;
//   InferenceResult({
//     required this.image,
//     required this.boxes,
//     required this.maskImages,
//     required this.scores,
//   });
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});
//   final String title;
//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   InferenceResult? result;

//   @override
//   Widget build(BuildContext context) {
//     final screenW = MediaQuery.of(context).size.width;
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.title)),
//       body: Center(
//         child: result == null
//             ? const Text('Press ▶ to run segmentation inference')
//             : SizedBox(
//                 width: screenW,
//                 height: screenW * result!.image.height / result!.image.width,
//                 child: CustomPaint(
//                   painter: SegPainter(result!),
//                 ),
//               ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _inferAndPaint,
//         child: const Icon(Icons.play_arrow),
//       ),
//     );
//   }

//   Future<List<double>> imageToFloatTensor(ui.Image img) async {
//     final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
//     final rgba = Uint8List.view(bd!.buffer);
//     final r = <double>[], g = <double>[], b = <double>[];
//     for (int i = 0; i < rgba.length; i += 4) {
//       r.add(rgba[i] / 255.0);
//       g.add(rgba[i + 1] / 255.0);
//       b.add(rgba[i + 2] / 255.0);
//     }
//     return [...r, ...g, ...b];
//   }

//   Future<void> exportInferenceJson({
//     required List<List<double>> boxes,
//     required List<int> labels,
//     required List<double> scores,
//     required List<List<List<double>>> masks,
//   }) async {
//     final data = {
//       'boxes': boxes,
//       'labels': labels,
//       'scores': scores,
//       'masks':  masks,
//     };
//     final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

//     final dir = await getApplicationDocumentsDirectory();
//     final file = File('${dir.path}/inference_output.json');
//     await file.writeAsString(jsonStr);

//     print('✅ Inference JSON exported to: ${file.path}');
//   }

//   Future<ui.Image> mask2dToImage(List<List<double>> mask2D) async {
//     final Hm = mask2D.length, Wm = mask2D[0].length;
//     final pixels = Uint8List(Hm * Wm * 4);
//     for (int y = 0; y < Hm; y++) {
//       for (int x = 0; x < Wm; x++) {
//         final idx = (y * Wm + x) * 4;
//         final a = mask2D[y][x] > 0.5 ? 150 : 0;
//         pixels[idx] = 0;      // R
//         pixels[idx + 1] = 255; // G
//         pixels[idx + 2] = 0;   // B
//         pixels[idx + 3] = a;   // A
//       }
//     }
//     final completer = Completer<ui.Image>();
//     ui.decodeImageFromPixels(
//       pixels, Wm, Hm, ui.PixelFormat.rgba8888, (img) {
//       completer.complete(img);
//     });
//     return completer.future;
//   }

//   void _inferAndPaint() async {
//     // 1. Init ONNX Runtime
//     OrtEnv.instance.init();
//     final so = OrtSessionOptions();
//     final modelData = await rootBundle.load('assets/models/leaf_mask_rcnn.onnx');
//     final session = OrtSession.fromBuffer(
//       modelData.buffer.asUint8List(),
//       so,
//     );
//     final ro = OrtRunOptions();

//     // 2. Load image
//     final imgData = await rootBundle.load('assets/leaf3.jpg');
//     final ui.Image imgRaw = await decodeImageFromList(
//       imgData.buffer.asUint8List(),
//     );
//     final H = imgRaw.height, W = imgRaw.width;

//     // 3. Preprocess
//     final floats = await imageToFloatTensor(imgRaw);
//     final inputOrt = OrtValueTensor.createTensorWithDataList(
//       Float32List.fromList(floats),
//       [1, 3, H, W],
//     );

//     // 4. Run inference
//     final outputs = session.run(ro, {'input': inputOrt});
//     final boxes = (outputs[0]!.value as List).cast<List<double>>();
//     final labels  = (outputs[1]!.value as List).cast<int>();
//     final scores = (outputs[2]!.value as List).cast<double>();
//     final masks4D = outputs[3]!.value as List;
//     final rawMasks = masks4D.map<List<List<double>>>((det) {
//       final m2d = (det as List)[0] as List;
//       return (m2d as List).cast<List<double>>();
//     }).toList();
    
//     await exportInferenceJson(
//       boxes: boxes,
//       labels: labels,
//       scores: scores,
//       masks:  rawMasks,
//     );

//     // 5. Create mask UI images
//     final maskUiImages = await Future.wait(
//       rawMasks.map((m2d) => mask2dToImage(m2d)));

//     // cleanup
//     inputOrt.release();
//     ro.release();
//     so.release();
//     OrtEnv.instance.release();

//     // 6. Update state
//     setState(() {
//       result = InferenceResult(
//         image: imgRaw,
//         boxes: boxes,
//         maskImages: maskUiImages,
//         scores: scores,
//       );
//     });
//   }
// }

// class SegPainter extends CustomPainter {
//   final InferenceResult res;
//   SegPainter(this.res);

//   @override
//   void paint(Canvas canvas, Size size) {
//     // scale canvas to original image coords
//     final sx = size.width / res.image.width;
//     final sy = size.height / res.image.height;
//     canvas.save();
//     canvas.scale(sx, sy);

//     // draw original image
//     canvas.drawImage(res.image, Offset.zero, Paint());

//     final paintMask = Paint()..color = const ui.Color.fromARGB(255, 17, 66, 99).withOpacity(0.4);
//     final paintBox = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2 / sx
//       ..color = const ui.Color.fromARGB(255, 195, 38, 163);

//     for (int i = 0; i < res.boxes.length; i++) {
//       final b = res.boxes[i];
//       final score = res.scores[i];
//       if (score < 0.5) continue;

//       final x1 = b[0], y1 = b[1], x2 = b[2], y2 = b[3];
//       final w = x2 - x1, h = y2 - y1;

//       // draw mask via drawImageRect
//       final maskImg = res.maskImages[i];
//       canvas.drawImageRect(
//         maskImg,
//         Rect.fromLTWH(0, 0, maskImg.width.toDouble(), maskImg.height.toDouble()),
//         Rect.fromLTWH(x1, y1, w, h),
//         paintMask,
//       );

//       // draw box
//       canvas.drawRect(Rect.fromLTWH(x1, y1, w, h), paintBox);

//       // draw score
//       final tp = TextPainter(
//         text: TextSpan(
//           text: '${(score * 100).toStringAsFixed(0)}%',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 14 / sx,
//             shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout();
//       tp.paint(canvas, Offset(x1, y1 - tp.height));
//     }

//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter old) => true;
// }
