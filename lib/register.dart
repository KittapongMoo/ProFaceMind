import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
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
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));
  bool _isDetectingFaces = false;
  List<Face> _faces = [];
  String? _capturedImagePath; // Store captured image path

  @override
  void initState() {
    super.initState();
    // Force portrait orientation.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  /// Initialize Camera
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

  /// Switch Between Front and Back Cameras
  Future<void> _switchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _setCamera(_isFrontCamera ? 1 : 0);
  }

  /// Set Camera by Index
  Future<void> _setCamera(int cameraIndex) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    try {
      CameraDescription selectedCamera = _cameras![cameraIndex];
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // Use highest resolution for preview
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;

      // Start real-time face detection (only for overlay, no cropping).
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

  /// Face Detection Using ML Kit (only for overlay)
  Future<void> _detectFaces(CameraImage image) async {
    try {
      final InputImage inputImage = _convertCameraImage(image);
      final List<Face> detectedFaces =
      await _faceDetector.processImage(inputImage);
      setState(() {
        _faces = detectedFaces;
      });
    } catch (e) {
      print("Error detecting faces: $e");
    }
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage _convertCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final int sensorOrientation =
        _cameraController!.description.sensorOrientation;
    InputImageRotation rotation = sensorOrientation == 90
        ? InputImageRotation.rotation90deg
        : sensorOrientation == 270
        ? InputImageRotation.rotation270deg
        : InputImageRotation.rotation0deg;
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// Capture and Save Image (no face cropping)
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

  /// Save Image to Gallery with Correct Orientation
  Future<String> _saveImageToGallery(String imagePath) async {
    try {
      final Directory directory = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final String newPath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await File(imagePath).readAsBytes();
      img.Image? capturedImage = img.decodeImage(bytes);
      if (capturedImage == null) {
        print("Error decoding image.");
        return "";
      }
      // Correct orientation and flip for front camera.
      img.Image orientedImage = img.bakeOrientation(capturedImage);
      if (_isFrontCamera) {
        orientedImage = img.flipHorizontal(orientedImage);
      }
      final orientedBytes = img.encodeJpg(orientedImage);
      final File newImage = await File(newPath).writeAsBytes(orientedBytes);
      print("Image saved successfully: $newPath");
      return newPath;
    } catch (e) {
      print("Error saving image: $e");
      return "";
    }
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Camera preview size (landscape) and calculations.
    final previewSize = _cameraController!.value.previewSize!;
    final double cameraAspectRatio = previewSize.width / previewSize.height;
    final Size screenSize = MediaQuery.of(context).size;
    final double screenAspectRatio = screenSize.width / screenSize.height;
    double scale = cameraAspectRatio / screenAspectRatio;
    double extraZoomFactor = 0.82;
    scale *= extraZoomFactor;
    final int sensorOrientation =
        _cameraController!.description.sensorOrientation;
    double rotationAngle = 0;
    if (sensorOrientation == 90) {
      rotationAngle = math.pi / 2;
    } else if (sensorOrientation == 270) {
      rotationAngle = -math.pi / 2;
    }
    final bool isFrontCamera = _cameraController!.description.lensDirection ==
        CameraLensDirection.front;
    final Matrix4 transformMatrix = isFrontCamera
        ? Matrix4.rotationY(math.pi) * Matrix4.rotationZ(rotationAngle)
        : Matrix4.rotationZ(rotationAngle);
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Transform.scale(
            scale: scale * extraZoomFactor,
            child: Center(
              child: AspectRatio(
                aspectRatio: cameraAspectRatio,
                child: Transform(
                  alignment: Alignment.center,
                  transform: transformMatrix,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),
        );
      },
    );
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
          // Fullscreen camera preview.
          Positioned.fill(child: _buildCameraPreview()),
          // Face detection overlay.
          if (_isCameraInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: FacePainter(
                  _faces,
                  _cameraController!.value.previewSize!,
                  _isFrontCamera,
                ),
              ),
            ),
          // Switch camera button.
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
          // Capture button.
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
          // Display captured image thumbnail.
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

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool isFrontCamera;

  FacePainter(this.faces, this.imageSize, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    double scaleX = size.width / imageSize.height;
    double scaleY = size.height / imageSize.width;

    for (var face in faces) {
      Rect rect = face.boundingBox;
      // Scale rectangle to match preview.
      Rect scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      // Flip horizontally for front camera.
      if (isFrontCamera) {
        scaledRect = Rect.fromLTRB(
          size.width - scaledRect.right,
          scaledRect.top,
          size.width - scaledRect.left,
          scaledRect.bottom,
        );
      }
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) => true;
}
