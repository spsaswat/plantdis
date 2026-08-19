import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/models/batch_segmentation_request.dart';
import 'package:flutter_test_application_1/utils/npy_mask_reader.dart';
import 'package:flutter_test_application_1/views/drone_path_check_web.dart'
    if (dart.library.io) 'package:flutter_test_application_1/utils/drone_image_detector.dart';

import 'package:flutter_test_application_1/views/pages/batch_processing_page.dart';
import 'package:flutter_test_application_1/views/pages/chat_page.dart';
import 'package:flutter_test_application_1/views/pages/mask_review_page.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:flutter_test_application_1/views/pages/manual_segmentation_page.dart';
import 'package:flutter_test_application_1/views/pages/segmentation_mode_page.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/progress_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'pages/take_picture_page.dart';
import 'widgets/navbar_widget.dart';

import '../data/notifiers.dart';
import 'widgets/drawer_widget.dart';

import 'pages/home_page.dart';
import 'pages/profile_page.dart';

List<Widget> pages = [const HomePage(), const ChatPage(), const ProfilePage()];

bool get _isDesktopHost =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  XFile? xfile;
  final PlantService _plantService = PlantService();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const AppbarWidget(),

        drawer: const DrawerWidget(),

        body: ValueListenableBuilder(
          valueListenable: selectedPageNotifier,
          builder: (BuildContext context, dynamic selectedPage, Widget? child) {
            return pages.elementAt(selectedPage);
          },
        ),

        floatingActionButton: ValueListenableBuilder(
          valueListenable: selectedPageNotifier,
          builder: (context, selectedPage, child) {
            return selectedPage == 0
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'upload_image',
                      tooltip: 'Upload from Gallery',
                      onPressed: () => _pickImageFromGallery(),
                      child: const Icon(Icons.photo_library),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: 'take_picture',
                      tooltip:
                          _isDesktopHost
                              ? 'Select drone image'
                              : 'Take Picture',
                      // Multi-color SVG: avoid FAB foreground tinting the whole icon black.
                      foregroundColor: Colors.transparent,
                      onPressed:
                          () =>
                              _isDesktopHost
                                  ? _pickDroneImageFromGallery()
                                  : _showCamera(),
                      child:
                          _isDesktopHost
                              ? SvgPicture.asset(
                                'assets/images/drones_img.svg',
                                width: 32,
                                height: 32,
                                fit: BoxFit.contain,
                              )
                              : Icon(
                                Icons.add_a_photo,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                    ),
                  ],
                )
                : const SizedBox();
          },
        ),

        bottomNavigationBar: const NavBarWidget(),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      await _processPickedImage(pickedFile, notes: 'Uploaded from gallery');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        'Error picking image: ${e.toString()}\n\nPlease check permissions.',
      );
    }
  }

  Future<void> _pickDroneImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      final isDrone = await isDroneImageForPath(pickedFile.path);
      if (!mounted) return;

      if (!isDrone) {
        _showDroneRequiredDialog();
        return;
      }

      final localBytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      final mode = await Navigator.of(context).push<SegmentationMode>(
        MaterialPageRoute(
          builder: (context) => SegmentationModePage(imageBytes: localBytes),
        ),
      );
      if (!mounted || mode == null) return;

      if (mode == SegmentationMode.manual) {
        await _openManualSegmentation(pickedFile, localBytes);
      } else {
        await _openAutomaticSegmentation(pickedFile, localBytes);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        'Error picking image: ${e.toString()}\n\nPlease check permissions.',
      );
    }
  }

  Future<void> _openManualSegmentation(
    XFile pickedFile,
    Uint8List localBytes,
  ) async {
    var uploadDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _plantService.uploadImageForManualLabelling(
        image: pickedFile,
        notes: 'Uploaded drone image for manual segmentation',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      uploadDialogVisible = false;

      final request = await Navigator.of(
        context,
      ).push<BatchSegmentationRequest>(
        MaterialPageRoute(
          builder:
              (context) => ManualSegmentationPage(
                imageId: result['imageId'] as String,
                plantId: result['plantId'] as String,
                imageUrl: result['downloadUrl'] as String,
                imageBytes: localBytes,
              ),
        ),
      );
      if (!mounted || request == null) return;
      await _handleBatchProcessingRequest(request);
    } catch (e) {
      if (!mounted) return;
      if (uploadDialogVisible) {
        Navigator.of(context).pop();
      }
      _showErrorDialog(
        'Error preparing image for labelling: ${e.toString()}\n\nPlease try again.',
      );
    }
  }

  /// Loads SAM masks from a `.npy` file the user picked and opens the mask
  /// review/editing page.
  ///
  /// The file is parsed and validated *before* the drone image is uploaded, so
  /// an unusable mask file leaves nothing behind in storage.
  Future<void> _openAutomaticSegmentation(
    XFile pickedFile,
    Uint8List localBytes,
  ) async {
    final maskFile = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'NumPy mask', extensions: ['npy']),
      ],
    );
    if (maskFile == null || !mounted) return;

    var dialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ProgressDialog(message: 'Reading SAM masks…'),
    );

    void closeDialog() {
      if (dialogVisible) {
        Navigator.of(context).pop();
        dialogVisible = false;
      }
    }

    try {
      // instantiateImageCodec applies EXIF orientation, exactly like the cv2
      // read that produced the masks and like decodeOriented downstream, so
      // these are the dimensions the mask grid must match.
      final imageSize = await _decodeImageSize(localBytes);
      final parsed = await NpyMaskReader.readSamMasks(maskFile.path);
      if (!mounted) return;

      final imageWidth = imageSize.width.round();
      final imageHeight = imageSize.height.round();
      if (parsed.maskWidth != imageWidth || parsed.maskHeight != imageHeight) {
        closeDialog();
        final transposed =
            parsed.maskWidth == imageHeight && parsed.maskHeight == imageWidth;
        _showErrorDialog(
          'The mask file is ${parsed.maskWidth} x ${parsed.maskHeight} but the '
          'selected image is $imageWidth x $imageHeight.'
          '${transposed ? '\n\nThe dimensions are swapped — the masks were '
              'likely generated from a differently rotated copy of this '
              'image.' : ''}'
          '\n\nGenerate the masks from this exact image and try again.',
        );
        return;
      }
      if (parsed.masks.isEmpty) {
        closeDialog();
        _showErrorDialog(
          'The mask file contains no non-empty masks.\n\nCheck that the file '
          'was saved after running SAM on this image.',
        );
        return;
      }

      final result = await _plantService.uploadImageForManualLabelling(
        image: pickedFile,
        notes: 'Uploaded drone image for automatic segmentation',
      );
      if (!mounted) return;
      closeDialog();

      final request = await Navigator.of(
        context,
      ).push<BatchSegmentationRequest>(
        MaterialPageRoute(
          builder:
              (context) => MaskReviewPage(
                imageId: result['imageId'] as String,
                plantId: result['plantId'] as String,
                imageUrl: result['downloadUrl'] as String,
                imageBytes: localBytes,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                initialMasks: parsed.masks,
                droppedEmptyCount: parsed.droppedEmptyCount,
              ),
        ),
      );
      if (!mounted || request == null) return;
      await _handleBatchProcessingRequest(request);
    } on NpyFormatException catch (e) {
      if (!mounted) return;
      closeDialog();
      _showErrorDialog(e.message);
    } catch (e) {
      if (!mounted) return;
      closeDialog();
      _showErrorDialog(
        'Error reading the mask file: ${e.toString()}\n\nPlease try again.',
      );
    }
  }

  Future<Size> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } finally {
      codec.dispose();
    }
  }

  /// Hands the labelled regions to the batch pipeline (#152). The request
  /// already contains the persisted main-image ID and normalized label
  /// positions, so the batch module owns everything from here.
  Future<void> _handleBatchProcessingRequest(
    BatchSegmentationRequest request,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BatchProcessingPage(request: request),
      ),
    );
  }

  Future<void> _processPickedImage(
    XFile pickedFile, {
    required String notes,
  }) async {
    setState(() {
      xfile = pickedFile;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _plantService.uploadAndAnalyzeImage(
        image: pickedFile,
        notes: notes,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (result.containsKey('plantId')) {
        final localBytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SegmentPage(
                  imgSrc: result['downloadUrl'],
                  id: result['imageId'],
                  plantId: result['plantId'],
                  localImageBytes: localBytes,
                ),
          ),
        );
      } else {
        _showErrorDialog(
          'Upload and analysis completed but result was unexpected.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showErrorDialog(
        'Error during upload/analysis: ${e.toString()}\n\nPlease try again.',
      );
    }
  }

  Future<void> _showCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _showErrorDialog('No cameras found on your device');
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      if (!mounted) return;

      final XFile? capturedImageFile = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TakePicturePage(camera: camera),
        ),
      );

      if (capturedImageFile == null) return;
      if (!mounted) return;

      await _processPickedImage(
        capturedImageFile,
        notes: 'Captured from camera',
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        'Error accessing camera: ${e.toString()}\n\nPlease ensure permissions are granted and using HTTPS if on web.',
      );
    }
  }

  void _showDroneRequiredDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Notice'),
            content: const Text(
              'Please select an image captured by a drone camera.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Camera Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
