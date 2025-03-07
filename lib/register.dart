import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math; // Import math for rotation

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

  Future<void> _initializeCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      print("Camera permission denied");
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        CameraDescription selectedCamera = _cameras![_isFrontCamera ? 1 : 0];

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.max, // ✅ Use highest resolution for best preview
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
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _detectFaces(CameraImage image) async {
    final InputImage inputImage = InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg, // ✅ Fix rotation issue
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    final faces = await _faceDetector.processImage(inputImage);
    setState(() {
      _faces = faces;
    });
  }

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

  /// **🔄 Apply Flip for Front Camera While Keeping Rotation**
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
            fit: BoxFit.cover, // ✅ Ensures full-screen camera preview
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
          Positioned.fill(child: _buildCameraPreview()), // ✅ Camera preview with flipping & rotation

          // Face detection overlay
          if (_isCameraInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: FacePainter(_faces),
              ),
            ),

          // Capture button
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

// **Face Painter for Bounding Box**
class FacePainter extends CustomPainter {
  final List<Face> faces;
  FacePainter(this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var face in faces) {
      final rect = face.boundingBox;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}
