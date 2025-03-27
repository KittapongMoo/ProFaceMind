import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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

  // Face detection fields.
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableTracking: true,
    ),
  );
  bool _isDetectingFaces = false;
  List<Face> _faces = [];

  Future<String?>? _lastImageFuture;

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
      if (_cameras!.isNotEmpty) {
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
        await _cameraController!
            .lockCaptureOrientation(DeviceOrientation.portraitUp);

        // Start image stream for face detection.
        _cameraController!.startImageStream((CameraImage cameraImage) {
          if (!_isDetectingFaces) {
            _detectFacesFromCamera(cameraImage);
          }
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
  InputImage? _convertCameraImage(
      CameraImage image, CameraDescription camera) {
    try {
      final int ySize = image.planes[0].bytes.length;
      final int uvSize = image.planes[1].bytes.length + image.planes[2].bytes.length;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      // Copy Y plane.
      nv21.setRange(0, ySize, image.planes[0].bytes);

      int offset = ySize;
      final int uvPixelStride = image.planes[1].bytesPerPixel!;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvHeight = image.height ~/ 2;
      final int uvWidth = image.width ~/ 2;

      for (int row = 0; row < uvHeight; row++) {
        final int rowOffset1 = row * image.planes[1].bytesPerRow;
        final int rowOffset2 = row * image.planes[2].bytesPerRow;
        for (int col = 0; col < uvWidth; col++) {
          nv21[offset++] =
          image.planes[1].bytes[rowOffset1 + col * uvPixelStride];
          nv21[offset++] =
          image.planes[2].bytes[rowOffset2 + col * uvPixelStride];
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
      final inputImage =
      _convertCameraImage(cameraImage, _cameraController!.description);
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

  Widget _buildCameraPreview(BuildContext context) {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
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

    final bool isFrontCamera =
        _cameraController!.description.lensDirection == CameraLensDirection.front;
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera preview.
                    Transform(
                      alignment: Alignment.center,
                      transform: transformMatrix,
                      child: CameraPreview(_cameraController!),
                    ),
                    // Face painting overlay.
                    CustomPaint(
                      painter: FacePainter(
                        faces: _faces,
                        // Swap width/height if needed.
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview with face paint overlay.
          Positioned.fill(child: _buildCameraPreview(context)),
          // The rest of your UI (buttons, navigation, etc.)
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
                            // Title and close button.
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
                  // Use the cached future.
                  future: _lastImageFuture,
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
                      // There is a last image.
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
                    // No image found: show a placeholder.
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
}

/// A custom painter that rotates the face bounding boxes 90° clockwise and mirrors them.
/// It draws the boxes over the preview based on the provided face detection results.
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
  /// Transformation: (x, y) => (y, originalWidth - x)
  Rect _rotateRect90(Rect rect, Size originalSize) {
    double newLeft = rect.top;
    double newTop = originalSize.width - rect.right;
    double newRight = rect.bottom;
    double newBottom = originalSize.width - rect.left;
    return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

  /// Mirrors a rectangle both horizontally and vertically in the rotated coordinate system.
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

    // After a 90° clockwise rotation, the effective dimensions swap.
    // rotatedWidth becomes the original image height and rotatedHeight becomes the original image width.
    double rotatedWidth = imageSize.height;
    double rotatedHeight = imageSize.width;

    // Scale factors to map rotated coordinates to the canvas.
    final double scaleX = size.width / rotatedWidth;
    final double scaleY = size.height / rotatedHeight;

    for (var face in faces) {
      // Rotate the face bounding box.
      Rect rotatedRect = _rotateRect90(face.boundingBox, imageSize);

      // For front camera, mirror both horizontally and vertically.
      if (isFrontCamera) {
        rotatedRect = _mirrorRectBoth(rotatedRect, rotatedWidth, rotatedHeight);
      }

      // Scale the rotated (and mirrored) rectangle.
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
