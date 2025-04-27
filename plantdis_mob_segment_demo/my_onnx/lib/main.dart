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
