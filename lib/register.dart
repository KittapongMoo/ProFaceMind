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
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math' as math;

import 'fillinfo.dart'; // Make sure FillInfoPage({required this.userId}) is defined

/// Make sure you set this in main.dart:
/// MaterialApp(navigatorKey: navigatorKey, home: RegisterPage())
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
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate, // accurate for better detection
      enableTracking: true,
    ),
  );
  bool _isDetectingFaces = false;
  List<Face> _faces = [];
  bool _processingImage = false;

  // List to store the face vectors (each from one image)
  List<List<double>> _faceVectors = [];

  // ImagePicker for gallery selection
  final ImagePicker _picker = ImagePicker();

  // Improved conversion function for camera images
  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final imageRotation = _getInputImageRotation(camera.sensorOrientation);
    if (imageRotation == null) return null;

    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return null;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  // Helper function to get the image rotation
  InputImageRotation _getInputImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

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

  @override
  void dispose() {
    _faceDetector.close();
    _cameraController?.dispose();
    Tflite.close();
    super.dispose();
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
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Find the front camera
        int frontCameraIndex = _cameras!
            .indexWhere((camera) => camera.lensDirection == CameraLensDirection.front);
        await _setCamera(frontCameraIndex != -1 ? frontCameraIndex : 0);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  /// Switch Between Front and Back Cameras
  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });

    int cameraIndex = 0;
    for (int i = 0; i < _cameras!.length; i++) {
      if ((_isFrontCamera && _cameras![i].lensDirection == CameraLensDirection.front) ||
          (!_isFrontCamera && _cameras![i].lensDirection == CameraLensDirection.back)) {
        cameraIndex = i;
        break;
      }
    }
    await _setCamera(cameraIndex);
  }

  Future<void> _detectFacesFromCamera(CameraImage cameraImage) async {
    if (_isDetectingFaces) return;
    _isDetectingFaces = true;

    try {
      final inputImage = _convertCameraImage(cameraImage, _cameraController!.description);
      if (inputImage == null) {
        _isDetectingFaces = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _faces = faces;
        });
      }
    } catch (e) {
      print("Error detecting faces: $e");
    } finally {
      _isDetectingFaces = false;
    }
  }

  /// Set Camera by Index
  Future<void> _setCamera(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    try {
      CameraDescription selectedCamera = _cameras![cameraIndex];
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high, // high resolution for better face detection
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();

      // Start image stream
      _cameraController!.startImageStream((CameraImage cameraImage) {
        _detectFacesFromCamera(cameraImage);
      });

      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _isFrontCamera =
            selectedCamera.lensDirection == CameraLensDirection.front;
      });
    } catch (e) {
      print('Error setting camera: $e');
    }
  }

  /// Validate that the given image file contains at least one face.
  Future<bool> _validateFace(File imageFile) async {
    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (e) {
      print('Error validating face: $e');
      return false;
    }
  }

  /// Show error popup if the image cannot be used.
  void _showErrorPopup(String message) {
    // Use navigatorKey.currentContext! instead of local context
    if (navigatorKey.currentContext != null) {
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
  }

  /// Show progress indicator
  void _showProgressIndicator(String message) {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(message),
              ],
            ),
          );
        },
      );
    }
  }

  /// Hide any open dialog
  void _hideDialog() {
    if (navigatorKey.currentContext != null &&
        Navigator.of(navigatorKey.currentContext!).canPop()) {
      Navigator.of(navigatorKey.currentContext!).pop();
    }
  }

  /// Capture a picture using the camera.
  Future<void> _takePicture() async {
    if (_processingImage) return;

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorPopup("Camera is not initialized");
      return;
    }

    if (_cameraController!.value.isTakingPicture) return;

    setState(() {
      _processingImage = true;
    });

    try {
      _showProgressIndicator("Processing image...");

      // Stop the stream before taking picture
      await _cameraController!.stopImageStream();

      // Wait a bit for the stream to stop
      await Future.delayed(Duration(milliseconds: 200));

      final XFile imageFile = await _cameraController!.takePicture();

      // Process the captured image
      await _processCapturedImage(File(imageFile.path));

      // Restart the stream
      _cameraController!.startImageStream((CameraImage cameraImage) {
        _detectFacesFromCamera(cameraImage);
      });
    } catch (e) {
      print('Error capturing image: $e');
      _hideDialog();
      _showErrorPopup("Error capturing image: $e");
    } finally {
      setState(() {
        _processingImage = false;
      });
    }
  }

  Future<void> _pickImage() async {
    if (_processingImage) return;

    setState(() {
      _processingImage = true;
    });

    try {
      final XFile? imageFile = await _picker.pickImage(source: ImageSource.gallery);
      if (imageFile != null) {
        _showProgressIndicator("Processing image...");
        await _processCapturedImage(File(imageFile.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorPopup("Error picking image: $e");
    } finally {
      setState(() {
        _processingImage = false;
      });
    }
  }

  /// Process the captured/selected image: validate face, convert to vector, and store.
  Future<void> _processCapturedImage(File imageFile) async {
    try {
      bool valid = await _validateFace(imageFile);
      _hideDialog();

      if (!valid) {
        _showErrorPopup("No face detected in this image");
        return;
      }

      // Save image locally
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'user_face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = join(appDir.path, fileName);
      final File savedImage = await imageFile.copy(newPath);

      // Convert to proper format for TFLite
      final Uint8List imageBytes = await savedImage.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        _showErrorPopup("Failed to process image");
        return;
      }

      // Resize to the expected input size for MobileFaceNet (usually 112x112)
      final img.Image resizedImage = img.copyResize(decodedImage, width: 112, height: 112);
      final List<int> processedImageBytes = img.encodePng(resizedImage);
      final Uint8List processedBytes = Uint8List.fromList(processedImageBytes);

      List<double> vector = await _runFaceRecognition(processedBytes);

      // Check if vector contains valid values
      bool isValidVector = vector.any((value) => value != 0.0);
      if (!isValidVector) {
        _showErrorPopup(
            "Face recognition failed. Please try again with better lighting");
        return;
      }

      setState(() {
        _faceVectors.add(vector);
      });

      print("Captured image processed. Count: ${_faceVectors.length}/5");

      if (_faceVectors.length >= 5) {
        await _registerUserWithImages();
      }
    } catch (e) {
      print('Error processing image: $e');
      _showErrorPopup("Error processing image: $e");
    }
  }

  Future<void> _registerUserWithImages() async {
    try {
      _showProgressIndicator("Registering user...");

      // Compute average vector
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

      // Save image paths associated with this user
      final Directory appDir = await getApplicationDocumentsDirectory();
      final images = Directory(appDir.path)
          .listSync()
          .where((file) => file.path.contains('user_face_'))
          .toList();

      for (var imageFile in images) {
        await db.insert('user_images', {
          'user_id': userId,
          'image_path': imageFile.path,
        });
      }

      print("User registered with id: $userId");
      _hideDialog();

      // Navigate to FillInfoPage using the global navigator context
      if (navigatorKey.currentContext != null) {
        Navigator.pushReplacement(
          navigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (_) => FillInfoPage(userId: userId),
          ),
        );
      }
    } catch (e) {
      _hideDialog();
      print('Error registering user: $e');
      _showErrorPopup("Error registering user: $e");
    }
  }

  /// Use TFLite to run the face recognition model and return the face vector.
  Future<List<double>> _runFaceRecognition(Uint8List imageBytes) async {
    try {
      var recognitions = await Tflite.runModelOnBinary(
        binary: imageBytes,
        numResults: 1,
        threshold: 0.05,
      );

      if (recognitions == null || recognitions.isEmpty) {
        print("No recognitions returned from model");
        return List.filled(128, 0.0);
      }

      if (!recognitions.first.containsKey("output") ||
          recognitions.first["output"] == null ||
          recognitions.first["output"].isEmpty) {
        print("No output in recognition result");
        return List.filled(128, 0.0);
      }

      return List<double>.from(recognitions.first["output"]);
    } catch (e) {
      print("Error running face recognition: $e");
      return List.filled(128, 0.0);
    }
  }

  /// Initialize and return the local SQLite database.
  Future<Database> _getDatabase() async {
    try {
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

          await db.execute('''
            CREATE TABLE user_images (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER,
              image_path TEXT,
              FOREIGN KEY(user_id) REFERENCES users(id)
            )
          ''');
        },
      );
    } catch (e) {
      print("Error getting database: $e");
      throw e;
    }
  }

  /// Build the camera preview.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildCameraPreview(context)),
          // Instructions at the top
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Take 5 clear pictures of your face from different angles",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          // Switch camera button
          Positioned(
            top: 120,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'switch',
              backgroundColor: Colors.blue,
              child: const Icon(Icons.switch_camera),
              onPressed: _switchCamera,
            ),
          ),
          // Capture button
          Positioned(
            bottom: 50,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: FloatingActionButton(
              heroTag: 'capture',
              backgroundColor: _processingImage ? Colors.grey : Colors.black,
              child: _processingImage
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt),
              onPressed: _processingImage ? null : _takePicture,
            ),
          ),
          // Gallery button
          Positioned(
            bottom: 50,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'gallery',
              backgroundColor: _processingImage ? Colors.grey : Colors.green,
              child: const Icon(Icons.photo_library),
              onPressed: _processingImage ? null : _pickImage,
            ),
          ),
          // Image count indicator
          Positioned(
            top: 120,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    "Images: ${_faceVectors.length}/5",
                    style: const TextStyle(color: Colors.white),
                  ),
                  SizedBox(width: 5),
                  _faceVectors.length >= 5
                      ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : Icon(Icons.circle_outlined, color: Colors.white, size: 20),
                ],
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

    // The camera's preview size
    final previewSize = _cameraController!.value.previewSize!;
    final double cameraAspectRatio = previewSize.width / previewSize.height;

    // The screen size and aspect ratio
    final Size screenSize = MediaQuery.of(buildContext).size;
    final double screenAspectRatio = screenSize.width / screenSize.height;

    // Compute initial scale
    double scale = cameraAspectRatio / screenAspectRatio;

    // Optional extra zoom factor
    double extraZoomFactor = 0.82;
    // First multiply the scale by 0.82
    scale *= extraZoomFactor;

    // Determine rotation based on sensor orientation
    final int sensorOrientation = _cameraController!.description.sensorOrientation;
    double rotationAngle = 0;
    if (sensorOrientation == 90) {
      rotationAngle = math.pi / 2;
    } else if (sensorOrientation == 270) {
      rotationAngle = -math.pi / 2;
    }

    // Check if it is front camera to mirror horizontally
    final bool isFrontCamera =
        _cameraController!.description.lensDirection == CameraLensDirection.front;

    // Build a transform matrix that mirrors if front camera
    // plus rotates based on sensor orientation
    final Matrix4 transformMatrix = isFrontCamera
        ? Matrix4.rotationY(math.pi) * Matrix4.rotationZ(rotationAngle)
        : Matrix4.rotationZ(rotationAngle);

    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        return ClipRect(
          child: Transform.scale(
            // Apply the scale again so total factor is scale * extraZoomFactor
            scale: scale * extraZoomFactor,
            child: Center(
              child: AspectRatio(
                aspectRatio: cameraAspectRatio,
                child: Transform(
                  alignment: Alignment.center,
                  transform: transformMatrix,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera preview
                      CameraPreview(_cameraController!),

                      // Draw bounding boxes for detected faces
                      CustomPaint(
                        painter: FacePainter(
                          faces: _faces,
                          imageSize: Size(
                            // Note: swap width/height here if needed
                            previewSize.height,
                            previewSize.width,
                          ),
                          isFrontCamera: isFrontCamera,
                          screenSize: constraints.biggest,
                        ),
                      ),

                      // Optional face overlay circle
                      Center(
                        child: Container(
                          width: constraints.maxWidth * 0.7,
                          height: constraints.maxWidth * 0.7,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
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
  final Size screenSize;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.isFrontCamera,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (var face in faces) {
      // Convert coordinates from image to screen
      final double scaleX = size.width / imageSize.width;
      final double scaleY = size.height / imageSize.height;

      double left = face.boundingBox.left * scaleX;
      double top = face.boundingBox.top * scaleY;
      double right = face.boundingBox.right * scaleX;
      double bottom = face.boundingBox.bottom * scaleY;

      // Mirror if front camera
      if (isFrontCamera) {
        final double temp = left;
        left = size.width - right;
        right = size.width - temp;
      }

      final Rect scaledRect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
