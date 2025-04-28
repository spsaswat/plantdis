# my_onnx

A new Flutter project.

## Getting Started
Please first download the [leaf_mask_rcnn.onnx](https://anu365-my.sharepoint.com/:u:/g/personal/u7670021_anu_edu_au/ESFo4Dk_89xAvC28d8JXc0wBihtlitR60cfUnxZnwgvaNw?e=LHfAM6) model and put it in `assets/models`.

And you can change the image in `assets` to test different image.

**Implementation Steps:**

1. **Add Dependencies** (`pubspec.yaml`):
```yaml
dependencies:
  onnxruntime: ^1.4.1
```

2. **Model Integration**:
- Add model file to `assets/models/leaf_mask_rcnn.onnx`
- Update `pubspec.yaml` assets section:
```yaml
assets:
  - assets/models/leaf_mask_rcnn.onnx
  - assets/image.jpg
```

3. **Create Detection Service** (`lib/main.dart`):
```dart
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

Future<void> runOnnxModel() async {
  // Initialize environment
  OrtEnv.instance.init();

  // Load ONNX model from assets
  const assetFileName = 'assets/models/test.onnx';
  final rawAssetFile = await rootBundle.load(assetFileName);
  final bytes = rawAssetFile.buffer.asUint8List();

  // Create session
  final sessionOptions = OrtSessionOptions();
  final session = OrtSession.fromBuffer(bytes, sessionOptions);

  // Prepare input tensor
  final data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]; // Example input data
  final shape = [1, 2, 3];
  final inputOrt = OrtValueTensor.createTensorWithDataList(data, shape);
  final inputs = {'input': inputOrt};

  // Perform inference
  final runOptions = OrtRunOptions();
  final outputs = await session.runAsync(runOptions, inputs);

  // Release resources
  inputOrt.release();
  runOptions.release();
  outputs?.forEach((element) {
    element?.release();
  });

  // Release environment
  OrtEnv.instance.release();
}
```
4. **UI Integration** (Update existing detection screen):
-Parse output tensors: bounding boxes, masks, and scores
-Render masks and bounding boxes with CustomPainter

**Required Packages:**
- "onnxruntime": ONNX Runtime for Flutter inference
- "image_picker": For selecting or capturing images
- "image": For image preprocessing


**Notes:**
- Memory Management: Always call .release() on OrtValueTensor, OrtRunOptions, and OrtEnv to avoid memory leaks.
- Image Preprocessing: Ensure input image is converted to Float32 and normalized between 0 and 1.
