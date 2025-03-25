import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';

class TakePicturePage extends StatefulWidget {
  final CameraDescription camera;
  const TakePicturePage({Key? key, required this.camera}) : super(key: key);

  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  Future<void>? _initializeCameraControllerFuture;
  final PlantService _plantService = PlantService();
  bool _isUploading = false;
  String _errorMessage = '';
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _disposeCamera() {
    if (_cameraController != null) {
      _cameraController!.dispose();
      _cameraController = null;
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _disposeCamera();

      // Create camera controller with web-optimized settings
      final controller = CameraController(
        widget.camera,
        kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Store the controller
      _cameraController = controller;

      // Initialize the controller
      _initializeCameraControllerFuture = controller
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _hasPermission = true;
                _errorMessage = '';
              });
            }
          })
          .catchError((error) {
            print('Camera initialization error: $error');
            if (mounted) {
              setState(() {
                _errorMessage =
                    kIsWeb
                        ? 'Camera error: Please make sure you have granted camera permissions in your browser settings and are using HTTPS.'
                        : 'Camera error: $error';
              });
            }
            return null;
          });

      // Wait for initialization to complete
      await _initializeCameraControllerFuture;

      if (mounted && _cameraController != null) {
        // Additional camera settings for web
        if (kIsWeb) {
          await _cameraController!.setFlashMode(FlashMode.off);
          await _cameraController!.setExposureMode(ExposureMode.auto);
          await _cameraController!.setFocusMode(FocusMode.auto);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            kIsWeb
                ? 'Failed to initialize camera. Please ensure camera permissions are granted and you are using HTTPS.'
                : 'Failed to initialize camera: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _disposeCamera();
        return true;
      },
      child: Scaffold(
        appBar: AppbarWidget(),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_isUploading) {
      return Container(
        width: 56.0,
        height: 56.0,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          shape: BoxShape.circle,
        ),
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.0),
      );
    }

    return FloatingActionButton(
      child: const Icon(Icons.camera),
      onPressed:
          _cameraController?.value.isInitialized ?? false
              ? () => _takePicture(context)
              : null,
    );
  }

  Widget _buildBody() {
    if (_errorMessage.isNotEmpty) {
      return _buildErrorWidget();
    }

    return FutureBuilder<void>(
      future: _initializeCameraControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_cameraController?.value.isInitialized ?? false) {
            return Center(child: CameraPreview(_cameraController!));
          }
          return _buildErrorWidget(
            message: 'Camera failed to initialize. Please try again.',
          );
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              message ?? _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = '';
              });
              _initializeCamera();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _takePicture(BuildContext context) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorSnackBar('Camera is not initialized');
      return;
    }

    try {
      if (!_cameraController!.value.isTakingPicture && !_isUploading) {
        setState(() {
          _isUploading = true;
          _errorMessage = '';
        });

        final XFile image = await _cameraController!.takePicture();

        try {
          final result = await _plantService.uploadPlantImage(
            image,
            notes: 'Captured from camera app',
          );

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => SegmentPage(
                    imgSrc: result['downloadUrl'],
                    id: result['imageId'],
                    plantId: result['plantId'],
                  ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Error uploading image: $e';
          });
          _showErrorSnackBar('Error uploading image: $e');
        }
      } else {
        _showErrorSnackBar('Already taking or uploading a picture.');
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error taking picture: $e';
        });
        _showErrorSnackBar('Error taking picture: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
  }
}
