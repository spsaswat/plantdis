import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:tflite_flutter/tflite_flutter.dart';

/// ---- Project paths ----
const String kModelPath = 'models/background_detector_quant.tflite';
const String kTestRoot = 'final_test_data'; // contains has_plant/ and no_plant/
const List<String> kClassNames = ['has_plant', 'no_plant'];

/// ---- Evaluation knobs ----
const List<double> kThresholds = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8];
const double kMinAccuracyAtDefaultThreshold = 0.85; // quality gate
const (int, int) kInputSize = (224, 224);

void main() {
  group('TFLite model (pure Dart) evaluation', () {
    late Interpreter interpreter;
    late List<int> inputShape;
    late List<int> outputShape;

    setUpAll(() async {
      // Sanity checks
      expect(File(kModelPath).existsSync(), true,
          reason: 'Model file not found at $kModelPath');
      expect(Directory(kTestRoot).existsSync(), true,
          reason: 'Test data directory not found at $kTestRoot');

      // Load interpreter
      interpreter = await Interpreter.fromFile(File(kModelPath));
      inputShape = interpreter.getInputTensor(0).shape;
      outputShape = interpreter.getOutputTensor(0).shape;

      // Expect NHWC input and single sigmoid output
      expect(inputShape.length, anyOf([4, 3]));
      expect(outputShape.reduce((a, b) => a * b), 1,
          reason: 'Model output is expected to be a single sigmoid value.');
    });

    tearDownAll(() {
      interpreter.close();
    });

    test('multi-threshold metrics and quality gate', () async {
      final samples = await _loadDataset(kTestRoot);
      expect(samples.isNotEmpty, true, reason: 'No images found to evaluate.');

      final stopwatch = Stopwatch()..start();
      final probs = <double>[];
      final labels = <int>[];

      for (final s in samples) {
        final tensor = _preprocessToInput(s.imagePath);
        final prob = _infer(interpreter, tensor);
        probs.add(prob);           // probability of class "no_plant"
        labels.add(s.labelIndex);  // 0=has_plant, 1=no_plant
      }
      final totalMs = stopwatch.elapsedMilliseconds;

      // Evaluate for multiple thresholds
      for (final th in kThresholds) {
        final preds = probs.map((p) => p > th ? 1 : 0).toList();
        final metrics = _computeMetrics(labels, preds, numClasses: 2);

        // Print human-readable summary in test logs
        // (Helpful during local dev; CI can parse if needed)
        // ignore: avoid_print
        print('--- Threshold=$th ---');
        // ignore: avoid_print
        print('Accuracy: ${(metrics.accuracy * 100).toStringAsFixed(2)}%');
        // ignore: avoid_print
        print('Confusion Matrix: ${_formatCM(metrics.cm, kClassNames)}');
      }

      // Default threshold quality gate
      final defaultTh = 0.5;
      final defaultPreds = probs.map((p) => p > defaultTh ? 1 : 0).toList();
      final defaultMetrics =
          _computeMetrics(labels, defaultPreds, numClasses: 2);

      final avgMs = totalMs / samples.length;
      // ignore: avoid_print
      print('Avg inference time: ${avgMs.toStringAsFixed(2)} ms');

      expect(defaultMetrics.accuracy,
          greaterThanOrEqualTo(kMinAccuracyAtDefaultThreshold),
          reason:
              'Accuracy at threshold $defaultTh is too low: ${defaultMetrics.accuracy.toStringAsFixed(4)}');
    });
  });
}

/// Represents one sample in the dataset.
class _Sample {
  final String imagePath;
  final int labelIndex; // 0 or 1
  _Sample(this.imagePath, this.labelIndex);
}

/// Recursively read images from:
/// final_test_data/has_plant/*.{png,jpg,jpeg}
/// final_test_data/no_plant/*.{png,jpg,jpeg}
Future<List<_Sample>> _loadDataset(String root) async {
  final result = <_Sample>[];
  for (int label = 0; label < kClassNames.length; label++) {
    final cls = kClassNames[label];
    final dir = Directory(p.join(root, cls));
    if (!dir.existsSync()) continue;

    for (final ent in dir.listSync(recursive: true)) {
      if (ent is! File) continue;
      final lower = ent.path.toLowerCase();
      if (lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg')) {
        result.add(_Sample(ent.path, label));
      }
    }
  }
  return result;
}

/// Preprocess a file path into a float32 NHWC tensor of shape [1,H,W,3].
List<List<List<List<double>>>> _preprocessToInput(String imagePath) {
  final file = File(imagePath);
  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Failed to decode image: $imagePath');
  }

  // Resize
  final (w, h) = kInputSize;
  final resized = img.copyResize(decoded, width: w, height: h);

  // Convert to float32 [1,h,w,3], normalized to [0,1]
  final tensor = List.generate(
      1,
      (_) => List.generate(
          h,
          (y) => List.generate(w, (x) {
                final pixel = resized.getPixel(x, y);
                final r = img.getRed(pixel) / 255.0;
                final g = img.getGreen(pixel) / 255.0;
                final b = img.getBlue(pixel) / 255.0;
                return <double>[r, g, b];
              })));
  return tensor;
}

/// Run inference and return sigmoid probability for class "no_plant".
double _infer(Interpreter interpreter, Object inputTensor) {
  // create 2D List [[0.0]]
  final output = List.generate(1, (_) => List.filled(1, 0.0));
  interpreter.run(inputTensor, output);
  return (output[0][0] as num).toDouble();
}

/// Simple metrics holder.
class _Metrics {
  final double accuracy;
  final List<List<int>> cm;
  _Metrics(this.accuracy, this.cm);
}

/// Compute accuracy and confusion matrix.
_Metrics _computeMetrics(List<int> yTrue, List<int> yPred,
    {required int numClasses}) {
  assert(yTrue.length == yPred.length && yTrue.isNotEmpty);
  final n = yTrue.length;

  final cm = List.generate(
      numClasses, (_) => List.filled(numClasses, 0, growable: false),
      growable: false);

  var correct = 0;
  for (var i = 0; i < n; i++) {
    final t = yTrue[i];
    final p = yPred[i];
    if (t == p) correct++;
    cm[t][p] += 1;
  }
  return _Metrics(correct / n, cm);
}

String _formatCM(List<List<int>> cm, List<String> labels) {
  final buf = StringBuffer();
  final maxLabel = labels.fold<int>(0, (m, s) => math.max(m, s.length));
  String pad(String s) => s.padRight(maxLabel);
  buf.writeln();
  buf.writeln('      ' + labels.map(pad).join(' | '));
  for (var i = 0; i < cm.length; i++) {
    buf.writeln('${pad(labels[i])} : ${cm[i].map((v) => v.toString().padLeft(3)).join(' | ')}');
  }
  return buf.toString();
}

/// Tiny helper to reshape List (since we avoided extra packages).
extension _Reshape on List {
  List reshape(List<int> dims) {
    assert(dims.fold<int>(1, (a, b) => a * b) == length);
    List rec(List list, int d) {
      if (d == dims.length - 1) {
        final start = 0;
        final end = dims[d];
        final chunk = list.sublist(start, end);
        return chunk;
      }
      final size = dims.sublist(d + 1).fold<int>(1, (a, b) => a * b);
      final out = <dynamic>[];
      for (var i = 0; i < dims[d]; i++) {
        out.add(rec(list.sublist(i * size, (i + 1) * size), d + 1));
      }
      return out;
    }

    return rec(this, 0) as List;
  }
}
