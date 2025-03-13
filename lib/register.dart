import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'fillinfo.dart'; // Make sure FillInfoPage({required this.userId}) is defined

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  bool _isDetectingFaces = false;
  List<Face> _faces = [];

  // List to store the face vectors (each from one image)
  List<List<double>> _faceVectors = [];
  // ImagePicker for gallery selection
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Force portrait orientation.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
    _loadModel();
  }

  /// Load MobileFaceNet Model via TFLite
  Future<void> _loadModel() async {
    try {
      String? res = await Tflite.loadModel(
        model: "assets/MobileFaceNet.tflite",
      );
      print("MobileFaceNet model loaded: $res");
    } catch (e) {
      print("Error loading model: $e");
    }
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
        ResolutionPreset.max, // Use highest resolution for preview
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error setting camera: $e');
    }
  }

  /// Validate that the given image file contains at least one face.
  Future<bool> _validateFace(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final List<Face> faces = await _faceDetector.processImage(inputImage);
    return faces.isNotEmpty;
  }

  /// Show error popup if the image cannot be used.
  /// NOTE: We renamed the function parameter to 'dialogContext'
  /// to avoid overshadowing 'buildContext' from the build method.
  void _showErrorPopup(String message) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  /// Capture a picture using the camera.
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_cameraController!.value.isTakingPicture) return;
    try {
      final XFile imageFile = await _cameraController!.takePicture();
      await _processCapturedImage(File(imageFile.path));
    } catch (e) {
      print('Error capturing image: $e');
      _showErrorPopup("Error capturing image: $e"); // ✅ No context here
    }
  }

  Future<void> _pickImage() async {
    final XFile? imageFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (imageFile != null) {
      await _processCapturedImage(File(imageFile.path));
    } else {
      _showErrorPopup("No image selected."); // ✅ No context here
    }
  }

  /// Process the captured/selected image: validate face, convert to vector, and store.
  Future<void> _processCapturedImage(File imageFile) async {
    bool valid = await _validateFace(imageFile);
    if (!valid) {
      _showErrorPopup("Can't use this picture");
      return;
    }
    final Uint8List imageBytes = await imageFile.readAsBytes();
    List<double> vector = await _runFaceRecognition(imageBytes);
    _faceVectors.add(vector);
    print("Captured image processed. Count: ${_faceVectors.length}/5");
    if (_faceVectors.length >= 5) {
      await _registerUser(); // No context needed here!
    }
  }

  /// Use TFLite to run the face recognition model and return the face vector.
  Future<List<double>> _runFaceRecognition(Uint8List imageBytes) async {
    var recognitions = await Tflite.runModelOnBinary(
      binary: imageBytes, // Assumes imageBytes are preprocessed as needed
      numResults: 1,
      threshold: 0.05,
    );
    if (recognitions == null || recognitions.isEmpty) {
      return List.filled(128, 0.0);
    }
    return List<double>.from(recognitions.first["output"]);
  }

  /// Compute the average face vector from the 5 captured images,
  /// save the vector into a local database row, and navigate to FillInfoPage.
  Future<void> _registerUser() async {
    List<double> averageVector = List.filled(128, 0.0);
    for (var vector in _faceVectors) {
      for (int i = 0; i < vector.length; i++) {
        averageVector[i] += vector[i];
      }
    }
    for (int i = 0; i < averageVector.length; i++) {
      averageVector[i] /= _faceVectors.length;
    }

    final db = await _getDatabase();
    int userId = await db.insert('users', {
      'face_vector': jsonEncode(averageVector),
      'nickname': '',
      'name': '',
      'relation': '',
    });

    print("User registered with id: $userId");

    navigatorKey.currentState!.pushReplacement(
      MaterialPageRoute(
        builder: (_) => FillInfoPage(userId: userId),
      ),
    );
  }

  /// Initialize and return the local SQLite database.
  Future<Database> _getDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'facemind.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            face_vector TEXT,
            nickname TEXT,
            name TEXT,
            relation TEXT
          )
        ''');
      },
    );
  }

  /// Build the camera preview.
  @override
  Widget build(BuildContext buildContext) {
    // explicitly renamed
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildCameraPreview(buildContext)),
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
          Positioned(
            bottom: 50,
            left: MediaQuery.of(buildContext).size.width / 2 - 30,
            child: FloatingActionButton(
              heroTag: 'capture',
              backgroundColor: Colors.black,
              child: const Icon(Icons.camera_alt),
              onPressed: _takePicture,
            ),
          ),
          Positioned(
            bottom: 50,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'gallery',
              backgroundColor: Colors.green,
              child: const Icon(Icons.photo_library),
              onPressed: _pickImage,
            ),
          ),
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                "Images: ${_faceVectors.length}/5",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(BuildContext buildContext) {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewSize = _cameraController!.value.previewSize!;
    final double cameraAspectRatio = previewSize.width / previewSize.height;
    final Size screenSize = MediaQuery.of(buildContext).size;
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
      builder: (layoutContext, constraints) {
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
      Rect scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

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
