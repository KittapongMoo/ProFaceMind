import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;
  final FaceDetector _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
  bool _isDetectingFaces = false;
  List<Face> _faces = [];
  Uint8List? _croppedFace; // ✅ Store cropped face
  String? _capturedImagePath; // ✅ Store the captured image path

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  /// **🔄 Initialize Camera**
  Future<void> _initializeCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      print("Camera permission denied");
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        await _setCamera(_isFrontCamera ? 1 : 0);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  /// **🔀 Switch Between Front and Back Cameras**
  Future<void> _switchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _setCamera(_isFrontCamera ? 1 : 0);
  }

  /// **📷 Set Camera by Index**
  Future<void> _setCamera(int cameraIndex) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    try {
      CameraDescription selectedCamera = _cameras![cameraIndex];

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.max, // ✅ Highest resolution for best preview
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      // Start real-time face detection
      _cameraController!.startImageStream((CameraImage image) async {
        if (!_isDetectingFaces) {
          _isDetectingFaces = true;
          await _detectFaces(image);
          _isDetectingFaces = false;
        }
      });

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error setting camera: $e');
    }
  }

  /// **🤖 Face Detection Using ML Kit**
  Future<void> _detectFaces(CameraImage image) async {
    try {
      final InputImage inputImage = _convertCameraImage(image);
      final List<Face> detectedFaces =
          await _faceDetector.processImage(inputImage);

      setState(() {
        _faces = detectedFaces;
      });

      if (detectedFaces.isNotEmpty) {
        _cropFace(image, detectedFaces.first);
      }
    } catch (e) {
      print("Error detecting faces: $e");
    }
  }

  /// **📌 Convert CameraImage to InputImage (For ML Kit)**
  InputImage _convertCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// **📸 Capture and Save Image**
  Future<void> _takePicture() async {
    if (!_cameraController!.value.isTakingPicture) {
      try {
        final XFile image = await _cameraController!.takePicture();
        final String newPath = await _saveImageToGallery(image.path);

        setState(() {
          _capturedImagePath = newPath;
        });

        print("Photo saved: $newPath");
      } catch (e) {
        print('Error capturing image: $e');
      }
    }
  }

  /// **💾 Save Image to Mobile Gallery**
  Future<String> _saveImageToGallery(String imagePath) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String newPath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File newImage = await File(imagePath).copy(newPath);

      await GallerySaver.saveImage(newImage.path, albumName: "MyCameraApp");

      return newImage.path;
    } catch (e) {
      print("Error saving image: $e");
      return "";
    }
  }

  /// **✂️ Crop the detected face**
  Future<void> _cropFace(CameraImage image, Face face) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (var plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final Uint8List bytes = allBytes.done().buffer.asUint8List();

      // Convert bytes to an image
      img.Image? capturedImage = img.decodeImage(Uint8List.fromList(bytes));
      if (capturedImage == null) return;

      // Get face bounding box
      Rect faceRect = face.boundingBox;
      int x = faceRect.left.toInt();
      int y = faceRect.top.toInt();
      int w = faceRect.width.toInt();
      int h = faceRect.height.toInt();

      // Ensure cropping is within bounds
      x = math.max(0, x);
      y = math.max(0, y);
      w = math.min(capturedImage.width - x, w);
      h = math.min(capturedImage.height - y, h);

      // Crop the face
      img.Image croppedFace = img.copyCrop(
        capturedImage,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      // Convert cropped image to Uint8List
      Uint8List croppedBytes = Uint8List.fromList(img.encodeJpg(croppedFace));

      setState(() {
        _croppedFace = croppedBytes; // Store the cropped face image
      });

      print("Face cropped successfully");
    } catch (e) {
      print("Error cropping face: $e");
    }
  }

  /// **📷 Build Camera Preview**
  Widget _buildCameraPreview() {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(
          child:
              CircularProgressIndicator()); // Show loading indicator while initializing
    }

    return CameraPreview(_cameraController!);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
              child: _buildCameraPreview()), // ✅ Full-screen camera preview

          // Face detection overlay
          if (_isCameraInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: FacePainter(_faces),
              ),
            ),

          // **🔄 Switch Camera Button**
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'switch',
              backgroundColor: Colors.blue,
              child: const Icon(Icons.switch_camera),
              onPressed: _switchCamera,
            ),
          ),

          // **📸 Capture Button**
          Positioned(
            bottom: 50,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: FloatingActionButton(
              heroTag: 'capture',
              backgroundColor: Colors.black,
              child: const Icon(Icons.camera_alt),
              onPressed: _takePicture,
            ),
          ),

          // **🖼️ Show Captured Image**
          if (_capturedImagePath != null)
            Positioned(
              bottom: 50,
              right: 20,
              child: Image.file(
                File(_capturedImagePath!),
                width: 100,
                height: 100,
              ),
            ),
        ],
      ),
    );
  }
}

// **🎯 Face Detection Painter**
class FacePainter extends CustomPainter {
  final List<Face> faces;
  FacePainter(this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (var face in faces) {
      final rect = face.boundingBox;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}
