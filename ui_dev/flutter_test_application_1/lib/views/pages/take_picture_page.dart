// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

class TakePicturePage extends StatefulWidget {
  final CameraDescription camera;
  const TakePicturePage({super.key, required this.camera});

  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  Future<void>? _initializeCameraControllerFuture;
  // final PlantService _plantService = PlantService(); // Unused field
  // bool _isUploading = false; // Unused field
  String _errorMessage = '';
  // bool _hasPermission = false; // Unused field

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
                // _hasPermission = true; // Unused field
                _errorMessage = '';
              });
            }
          })
          .catchError((error) {
            logger.e('Camera initialization error: $error');
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _disposeCamera();
        }
      },
      child: Scaffold(
        appBar: const AppbarWidget(),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed:
          _cameraController?.value.isInitialized ?? false
              ? () => _takePicture()
              : null,
      child: const Icon(Icons.camera),
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
        return const Center(
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
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              message ?? _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = '';
              });
              _initializeCamera();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (mounted) {
        _showErrorSnackBar('Camera is not initialized');
      }
      return;
    }
    // Prevent taking multiple pictures if one is already being processed or a tap is in progress
    if (_cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      final XFile imageFile = await _cameraController!.takePicture();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(imageFile);
    } catch (e) {
      if (!mounted) {
        return;
      }

      if (kDebugMode) {
        logger.e('Error taking picture: $e');
      }

      _showErrorSnackBar('Failed to take picture: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
