import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';

class TakePicturePage extends StatefulWidget {
  final CameraDescription camera;
  const TakePicturePage({Key? key, required this.camera}) : super(key: key);

  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage> {
  late CameraController _cameraController;
  late Future _initializeCameraControllerFuture;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(widget.camera, ResolutionPreset.max);
    _initializeCameraControllerFuture = _cameraController.initialize();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarWidget(),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera),
        onPressed: () => _takePicture(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: FutureBuilder(
        future: _initializeCameraControllerFuture,
        builder: (context, snapshot) {
          return Center(
            child:
                snapshot.connectionState == ConnectionState.done
                    ? CameraPreview(_cameraController)
                    : CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  void _takePicture(BuildContext context) async {
    try {
      if (!_cameraController.value.isTakingPicture) {
        XFile image = await _cameraController.takePicture();
        if (!mounted) return;
        Navigator.pop(context, image);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Already taking a picture.')),
          );
      }
    } catch (e) {
      debugPrint('$e');
    }
  }
}
