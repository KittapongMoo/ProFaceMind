import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

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
  final FaceDetector _faceDetector =
  FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
  bool _isDetectingFaces = false;
  List<Face> _faces = [];

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
      final List<Face> detectedFaces = await _faceDetector.processImage(inputImage);

      setState(() {
        _faces = detectedFaces;
      });
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
      rotation: InputImageRotation.rotation0deg, // ✅ Fix rotation issue
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// **📸 Take Picture**
  Future<void> _takePicture() async {
    if (!_cameraController!.value.isTakingPicture) {
      try {
        final image = await _cameraController!.takePicture();
        print("Photo captured: ${image.path}");
      } catch (e) {
        print('Error capturing image: $e');
      }
    }
  }

  /// **🔄 Flip Camera Preview for Front Camera**
  Widget _buildCameraPreview() {
    if (_isCameraInitialized) {
      return Transform(
        alignment: Alignment.center,
        transform: _cameraController!.description.lensDirection == CameraLensDirection.front
            ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0)) // ✅ Flip horizontally for front camera
            : Matrix4.identity(),
        child: Transform.rotate(
          angle: _cameraController!.description.sensorOrientation == 90
              ? math.pi / 2 // ✅ Rotate correctly for portrait
              : _cameraController!.description.sensorOrientation == 270
              ? -math.pi / 2 // ✅ Adjust back camera
              : 0,
          child: FittedBox(
            fit: BoxFit.cover, // ✅ Full-screen preview
            child: SizedBox(
              width: 300,
              height: 300 / _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
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
          Positioned.fill(child: _buildCameraPreview()), // ✅ Full-screen camera preview

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
              onPressed: _switchCamera, // ✅ Switch camera function
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
      ..color = Colors.red // ✅ Change to red for better visibility
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
