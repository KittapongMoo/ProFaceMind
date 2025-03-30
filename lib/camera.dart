import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navigation.dart';
import 'profile.dart';
import 'register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setphonenum.dart';
import 'allregister.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:facemind/main.dart';

// Import ML Kit face detection:
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = false;
  XFile? _capturedImage;
  File? _galleryImage;
  int _sensorOrientation = 0;
  Interpreter? interpreter;

  // Face detection fields.
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableTracking: true,
    ),
  );
  bool _isDetectingFaces = false;
  List<Face> _faces = [];

  // Cache for last image path future.
  Future<String?>? _lastImageFuture;

  // Added flags and lists.
  bool _isRecognizing = false;
  bool _processingImage = false;
  List<List<double>> _faceVectors = [];

  @override
  void initState() {
    super.initState();
    // Lock orientation to portrait.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
    _lastImageFuture = _getLastImagePath();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        CameraDescription selectedCamera = _isFrontCamera
            ? _cameras!.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first)
            : _cameras!.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first);

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();

        // Lock preview to portrait.
        await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);

        // Start image stream for face detection.
        _cameraController!.startImageStream((CameraImage cameraImage) {
          _detectFacesFromCamera(cameraImage);
        });

        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
          _sensorOrientation = selectedCamera.sensorOrientation;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  /// Convert a [CameraImage] in YUV420 format to an [InputImage] for ML Kit.
  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final int ySize = image.planes[0].bytes.length;
      final int uvSize =
          image.planes[1].bytes.length + image.planes[2].bytes.length;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      // Copy Y plane.
      nv21.setRange(0, ySize, image.planes[0].bytes);

      int offset = ySize;
      final int uvPixelStride = image.planes[1].bytesPerPixel!;
      final int uvHeight = image.height ~/ 2;
      final int uvWidth = image.width ~/ 2;
      for (int row = 0; row < uvHeight; row++) {
        final int rowOffset1 = row * image.planes[1].bytesPerRow;
        final int rowOffset2 = row * image.planes[2].bytesPerRow;
        for (int col = 0; col < uvWidth; col++) {
          nv21[offset++] = image.planes[1].bytes[rowOffset1 + col * uvPixelStride];
          nv21[offset++] = image.planes[2].bytes[rowOffset2 + col * uvPixelStride];
        }
      }
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      // Get rotation based on sensor orientation.
      InputImageRotation imageRotation;
      switch (camera.sensorOrientation) {
        case 0:
          imageRotation = InputImageRotation.rotation0deg;
          break;
        case 90:
          imageRotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          imageRotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          imageRotation = InputImageRotation.rotation270deg;
          break;
        default:
          imageRotation = InputImageRotation.rotation0deg;
      }
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
      return InputImage.fromBytes(bytes: nv21, metadata: metadata);
    } catch (e) {
      print("Error converting camera image: $e");
      return null;
    }
  }

  /// Process the camera image to detect faces.
  Future<void> _detectFacesFromCamera(CameraImage cameraImage) async {
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
        // If a face is detected and we're not already recognizing, trigger recognition.
        if (faces.isNotEmpty && !_isRecognizing) {
          _recognizeFace();
        }
      }
    } catch (e) {
      print("Error detecting faces: $e");
    } finally {
      _isDetectingFaces = false;
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (!_cameraController!.value.isTakingPicture) {
      try {
        final image = await _cameraController!.takePicture();
        setState(() {
          _capturedImage = image;
        });
      } catch (e) {
        print('Error capturing image: $e');
      }
    }
  }

  void _switchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraInitialized = false;
    });
    await _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<Database> _getDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'facemind.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            face_vector TEXT,
            nickname TEXT,
            name TEXT,
            relation TEXT,
            primary_image TEXT
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
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion == 1 && newVersion == 2) {
          await db.execute('ALTER TABLE users ADD COLUMN primary_image TEXT');
        }
      },
    );
  }

  Future<String?> _getLastImagePath() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> result = await db.query(
      'user_images',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['image_path'] as String?;
    }
    return null;
  }

  Uint8List _imageToByteListFloat32(img.Image image, int inputSize, double mean, double std) {
    final Float32List convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final int pixel = image.getPixel(x, y);
        final double r = img.getRed(pixel).toDouble();
        final double g = img.getGreen(pixel).toDouble();
        final double b = img.getBlue(pixel).toDouble();
        convertedBytes[pixelIndex++] = (r - mean) / std;
        convertedBytes[pixelIndex++] = (g - mean) / std;
        convertedBytes[pixelIndex++] = (b - mean) / std;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  /// Build the camera preview.
  Widget _buildCameraPreview(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final previewSize = _cameraController!.value.previewSize!;
    final double cameraAspectRatio = previewSize.width / previewSize.height;
    final Size screenSize = MediaQuery.of(context).size;
    final double screenAspectRatio = screenSize.width / screenSize.height;
    double scale = cameraAspectRatio / screenAspectRatio;
    double extraZoomFactor = 0.72;
    scale *= extraZoomFactor;
    final int sensorOrientation = _cameraController!.description.sensorOrientation;
    double rotationAngle = 0;
    if (sensorOrientation == 90) {
      rotationAngle = math.pi / 2;
    } else if (sensorOrientation == 270) {
      rotationAngle = -math.pi / 2;
    }
    final bool isFrontCamera = _cameraController!.description.lensDirection == CameraLensDirection.front;
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),
                      CustomPaint(
                        painter: FacePainter(
                          faces: _faces,
                          imageSize: Size(previewSize.height, previewSize.width),
                          isFrontCamera: isFrontCamera,
                          screenSize: constraints.biggest,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview with face overlay.
          Positioned.fill(child: _buildCameraPreview(context)),
          // Profile button (top-left)
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                },
              ),
            ),
          ),
          // Phone button (top-right)
          Positioned(
            top: 40,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.red,
              child: IconButton(
                icon: const Icon(Icons.phone, color: Colors.white),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final name = prefs.getString('emergency_name') ?? 'ไม่พบชื่อ';
                  final relation = prefs.getString('emergency_relation') ?? 'ไม่พบความสัมพันธ์';
                  final phone = prefs.getString('emergency_phone') ?? 'ไม่พบเบอร์โทร';
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'เบอร์โทรศัพท์ฉุกเฉิน',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A2A43),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.close, size: 22, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$name ($relation)',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6B7280),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SetPhoneNumber()),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8, top: 2),
                                    child: CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Colors.blue,
                                      child: const Icon(Icons.edit, size: 25, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Flip camera button (top center)
          Positioned(
            top: 40,
            left: MediaQuery.of(context).size.width / 2 - 25,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.flip_camera_ios, color: Colors.black),
                onPressed: _switchCamera,
              ),
            ),
          ),
          // Bottom row with register, last image, map.
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Register button.
                FloatingActionButton(
                  heroTag: 'register',
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.how_to_reg),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterPage()),
                    );
                  },
                ),
                // Tappable rectangle for last image.
                FutureBuilder<String?>(
                  future: _lastImageFuture, // use cached future (do not invoke)
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AllRegisterPage()),
                          );
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AllRegisterPage()),
                          );
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(snapshot.data!)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AllRegisterPage()),
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                // Map button.
                FloatingActionButton(
                  heroTag: 'map',
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.map),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NavigationPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  // REAL-TIME FACE RECOGNITION FUNCTIONS
  //////////////////////////////////////////////////////////////////////////////

  /// Trigger face recognition in real time.
  Future<void> _recognizeFace() async {
    if (_isRecognizing) return;
    _isRecognizing = true;
    try {
      // Stop image stream to capture a clear frame.
      await _cameraController!.stopImageStream();
      // Capture the picture.
      final XFile imageFile = await _cameraController!.takePicture();
      print("Real-time picture taken: ${imageFile.path}");
      // Read and decode the image using package:image.
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        print("Failed to decode captured image");
        return;
      }
      // Use the first detected face bounding box.
      if (_faces.isEmpty) return;
      final face = _faces.first;
      Rect bbox = face.boundingBox;
      // Ensure the crop coordinates are within image bounds.
      int cropX = bbox.left.floor().clamp(0, decodedImage.width - 1);
      int cropY = bbox.top.floor().clamp(0, decodedImage.height - 1);
      int cropW = bbox.width.floor().clamp(0, decodedImage.width - cropX);
      int cropH = bbox.height.floor().clamp(0, decodedImage.height - cropY);
      final img.Image croppedImage = img.copyCrop(decodedImage, cropX, cropY, cropW, cropH);
      // Resize the cropped face to the expected input size for MobileFaceNet (112x112).
      final img.Image resizedFace = img.copyResize(croppedImage, width: 112, height: 112);
      final Uint8List processedBytes = _imageToByteListFloat32(resizedFace, 112, 127.5, 128.0);
      // Run recognition.
      List<double> vector = await _runFaceRecognition(processedBytes);
      print("💕💕💕💕Real-time face vector: $vector");
      if (vector.every((element) => element == 0)) {
        print("🦓🦓🦓🦓🦓Face vector is all zeros. Check image preprocessing.");
      }
      // Compare with database.
      Map<String, dynamic>? matchedUser = await _findMatchingUser(vector);
      if (matchedUser != null) {
        _showUserInfoOverlay(matchedUser, navigatorKey.currentContext!);
      }
    } catch (e) {
      print("Error in real-time recognition: $e");
    } finally {
      // Restart image stream.
      _cameraController!.startImageStream((CameraImage cameraImage) {
        _detectFacesFromCamera(cameraImage);
      });
      _isRecognizing = false;
    }
  }

  /// Run face recognition using tflite_flutter.
  Future<List<double>> _runFaceRecognition(Uint8List imageBytes) async {
    if (interpreter == null) {
      print("Interpreter not initialized");
      return List.filled(128, 0.0);
    }
    try {
      var input = imageBytes.buffer.asFloat32List().reshape([1, 112, 112, 3]);
      var output = List.filled(1 * 128, 0).reshape([1, 128]);
      interpreter!.run(input, output);
      return List<double>.from(output[0]);
    } catch (e) {
      print("Error running face recognition: $e");
      return List.filled(128, 0.0);
    }
  }

  /// Compute Euclidean distance between two vectors.
  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += math.pow(a[i] - b[i], 2);
    }
    return math.sqrt(sum);
  }

  /// Find a matching user in the database by comparing face vectors.
  Future<Map<String, dynamic>?> _findMatchingUser(List<double> vector) async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> users = await db.query('users');
    double threshold = 0.6; // You might try a higher threshold, e.g., 0.8
    Map<String, dynamic>? bestMatch;
    double bestDistance = double.infinity;
    for (var user in users) {
      String faceVectorJson = user['face_vector'];
      List<dynamic> stored = jsonDecode(faceVectorJson);
      List<double> storedVector = stored.map((e) => (e as num).toDouble()).toList();
      double dist = _euclideanDistance(vector, storedVector);
      print("Distance for user ${user['id']}: $dist");
      if (dist < threshold && dist < bestDistance) {
        bestDistance = dist;
        bestMatch = user;
      }
    }
    print("🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢Best distance: $bestDistance");
    return bestMatch;
  }

  /// Display an overlay with user information.
  void _showUserInfoOverlay(Map<String, dynamic> user, BuildContext overlayContext) {
    showDialog(
      context: overlayContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(user['nickname'] ?? 'Unknown'),
          content: Text("Name: ${user['name']}\nRelation: ${user['relation']}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }
}

/// A custom painter that rotates the face bounding boxes appropriately.
/// This FacePainter rotates each bounding box 90° clockwise using the transformation:
/// (x, y) → (y, originalWidth - x). For the front camera, it then mirrors the result
/// both horizontally and vertically.
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

  /// Rotates a rectangle 90° clockwise.
  /// Transformation: (x, y) becomes (y, originalWidth - x)
  Rect _rotateRect90(Rect rect, Size originalSize) {
    double newLeft = rect.top;
    double newTop = originalSize.width - rect.right;
    double newRight = rect.bottom;
    double newBottom = originalSize.width - rect.left;
    return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

  /// Mirrors a rectangle both horizontally and vertically.
  /// mirrorWidth and mirrorHeight are the dimensions of the rotated coordinate system.
  Rect _mirrorRectBoth(Rect rect, double mirrorWidth, double mirrorHeight) {
    return Rect.fromLTRB(
      mirrorWidth - rect.right,
      mirrorHeight - rect.bottom,
      mirrorWidth - rect.left,
      mirrorHeight - rect.top,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // After a 90° rotation, the effective dimensions swap:
    // rotatedWidth is the original image height and rotatedHeight is the original image width.
    double rotatedWidth = imageSize.height;
    double rotatedHeight = imageSize.width;
    // Scale factors to map the rotated coordinates to the canvas.
    final double scaleX = size.width / rotatedWidth;
    final double scaleY = size.height / rotatedHeight;
    for (var face in faces) {
      Rect rotatedRect = _rotateRect90(face.boundingBox, imageSize);
      if (isFrontCamera) {
        rotatedRect = _mirrorRectBoth(rotatedRect, rotatedWidth, rotatedHeight);
      }
      Rect scaledRect = Rect.fromLTRB(
        rotatedRect.left * scaleX,
        rotatedRect.top * scaleY,
        rotatedRect.right * scaleX,
        rotatedRect.bottom * scaleY,
      );
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
