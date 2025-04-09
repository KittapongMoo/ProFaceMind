import 'dart:async'; // For Timer
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';
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
import 'package:facemind/database_helper.dart';
import 'package:exif/exif.dart';

// Import ML Kit face detection:
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with RouteAware{
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = false;
  XFile? _capturedImage;
  File? _galleryImage;
  int _sensorOrientation = 0;
  Interpreter? interpreter;
  Uint8List? _processedFaceImage;

  // 👇 เพิ่มตรงนี้
  File? _profileImageFile;

  // Face detection fields.
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableTracking: true,
    ),
  );

  bool _isDetectingFaces = false;

  // We'll update _faces every time new faces are detected.
  List<Face> _faces = [];

  Future<String?>? _lastImageFuture;

  /// Store matched user info here (for overlay below); not used for FacePainter.
  Map<String, dynamic>? _matchedUser;

  Timer? _timer; // Timer for periodic recognition

  @override
  void initState() {
    super.initState();
    // Lock orientation to portrait.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
    _lastImageFuture = _getLastImagePath();
    _loadModel();
    _loadProfileImage();      // ✅ โหลดรูปโปรไฟล์  <<< ใส่ตรงนี้เลย
    // Start a timer to check for a face match every 10 seconds.
    _timer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      _recognizeFace();
    });
    // _checkHistoryDatabase();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('imagePath');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImageFile = File(imagePath);
      });
    } else {
      setState(() {
        _profileImageFile = null; // ใช้ไอคอนแทน
      });
    }
  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(this.context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // When another page is pushed on top, stop the image stream and cancel the timer.
    _cameraController?.stopImageStream();
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didPopNext() {
    // When returning to this page, restart the image stream and timer.
    _cameraController?.startImageStream((CameraImage cameraImage) {
      if (!_isDetectingFaces) {
        _detectFacesFromCamera(cameraImage);
      }
    });
    _loadProfileImage(); // ✅ โหลดรูปโปรไฟล์อีกครั้งเมื่อกลับเข้าหน้านี้
    _timer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      _recognizeFace();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Load MobileFaceNet Model via TFLite.
  Future<void> _loadModel() async {
    try {
      final modelData = await rootBundle.load('assets/MobileFaceNet.tflite');
      final buffer = modelData.buffer;
      interpreter = Interpreter.fromBuffer(buffer.asUint8List());
      print('✅ TFLite model loaded successfully from buffer!');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
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
          // Avoid multiple concurrent detections.
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

  Future<String?> _getLastImagePath() async {
    final db = await DatabaseHelper().database;
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

  /// Convert a CameraImage in YUV420 format to an InputImage.
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
    bool detecting = true;
    try {
      final inputImage =
      _convertCameraImage(cameraImage, _cameraController!.description);
      if (inputImage == null) {
        detecting = false;
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
      detecting = false;
    }
  }

  /// Build the camera preview with FacePainter overlay.
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
                child: Transform(
                  alignment: Alignment.center,
                  transform: transformMatrix,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera preview.
                      CameraPreview(_cameraController!),
                      // FacePainter draws bounding boxes for detected faces.
                      CustomPaint(
                        painter: FacePainter(
                          faces: _faces,
                          // Note: swap dimensions if needed.
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

  /// Trigger face recognition every 10 seconds.
  Future<void> _recognizeFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      // Capture the picture.
      final XFile imageFile = await _cameraController!.takePicture();
      print("Picture taken: ${imageFile.path}");

      // Read and decode the image.
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        print("Failed to decode captured image");
        return;
      }

      // Read EXIF data for orientation.
      final Map<String, IfdTag> exifData = await readExifFromBytes(bytes);
      int rotationAngle = 0;
      if (!_isFrontCamera) {
        // Use EXIF data if available.
        if (exifData.isNotEmpty && exifData.containsKey("Image Orientation")) {
          final orientation = exifData["Image Orientation"]?.printable;
          if (orientation == "Rotated 90 CW") {
            rotationAngle = 90;
          } else if (orientation == "Rotated 180") {
            rotationAngle = 180;
          } else if (orientation == "Rotated 270 CW") {
            rotationAngle = -90;
          }
        }
      } else {
        // For front-camera, force a rotation (adjust as needed).
        rotationAngle = -90;
      }

      // Rotate the decoded image accordingly.
      final img.Image orientedImage = (rotationAngle != 0)
          ? img.copyRotate(decodedImage, rotationAngle)
          : decodedImage;

      // *** FIX END ***

      // Apply rotation correction based on the sensor orientation.
      // if (_cameraController!.description.sensorOrientation == 90) {
      //   processedImage = img.copyRotate(processedImage, 90);
      // } else if (_cameraController!.description.sensorOrientation == 270) {
      //   processedImage = img.copyRotate(processedImage, -90);
      // } else if (_cameraController!.description.sensorOrientation == 180) {
      //   processedImage = img.copyRotate(processedImage, 180);
      // }

      // Use ML Kit to detect faces (using the image file path)
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      // If no face is detected, update overlay placeholders.
      if (faces.isEmpty) {
        setState(() {
          _matchedUser = {
            "nickname": "??",
            "name": "??",
            "relation": "??"
          };
        });
        return;
      }

      // Use the first detected face.
      // final face = faces.first;
      // Rect bbox = face.boundingBox;

      // Instead of cropping to the face bounding box, use the full processed image.
      final Uint8List fullImageBlob = Uint8List.fromList(img.encodePng(orientedImage));
      // Optionally, still perform face recognition using the cropped face if needed.
      // Resize the cropped face (if you still want to use it for recognition)...
      // Crop to face bounding box
      final Face face = faces.first;
      Rect box = face.boundingBox;

      // If using the front camera, mirror the bounding box.
      if (_isFrontCamera) {
        box = Rect.fromLTRB(
          orientedImage.width - box.right, // new left
          box.top,
          orientedImage.width - box.left,  // new right
          box.bottom,
        );
      }

      const margin = 20;
      int x = (box.left - margin).toInt().clamp(0, orientedImage.width);
      int y = (box.top - margin).toInt().clamp(0, orientedImage.height);
      int w = (box.width + 2 * margin).toInt();
      int h = (box.height + 2 * margin).toInt();
      if (x + w > orientedImage.width) {
        w = orientedImage.width - x;
      }
      if (y + h > orientedImage.height) {
        h = orientedImage.height - y;
      }

      final img.Image croppedFace = img.copyCrop(orientedImage, x, y, w, h);
      final img.Image resizedFace = img.copyResize(croppedFace, width: 112, height: 112);

      // Save the cropped & resized face image for preview.
      _processedFaceImage = Uint8List.fromList(img.encodeJpg(resizedFace));
      setState(() {}); // Update UI to show the cropped face preview.


      final Uint8List processedBytes = _imageToByteListFloat32(resizedFace, 112, 127.5, 128.0);
      List<double> vector = await _runFaceRecognition(processedBytes);

// ✅ Normalize vector
      final double norm = math.sqrt(vector.fold(0, (sum, val) => sum + val * val));
      if (norm > 0) {
        vector = vector.map((e) => e / norm).toList();
      }
      print("Face vector: $vector");
      if (vector.every((element) => element == 0)) {
        print("Face vector is all zeros. Check image preprocessing.");
      }

      // Compare with database.
      Map<String, dynamic>? matchedUser = await _findMatchingUser(vector);

      // Always save the current face image blob in history.
      // If no match is found, you can use a default user id (for example, 0) or handle it as an unknown user.
      if (matchedUser == null) {
        await _saveHistory(0, fullImageBlob); // 0 indicates unknown user, adjust as needed.
        setState(() {
          _matchedUser = {
            "nickname": "??",
            "name": "??",
            "relation": "??"
          };
        });
      } else {
        // await _saveHistory(matchedUser['id'] as int, fullImageBlob);
        await _saveHistory(matchedUser['userId'] as int, fullImageBlob);
        setState(() {
          _matchedUser = matchedUser;
        });
      }
    } catch (e) {
      print("❌❌❌Error in recognition: $e");
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

  /// Find a matching user in the database by comparing face vectors.
  Future<Map<String, dynamic>?> _findMatchingUser(List<double> queryVector) async {
    final db = await DatabaseHelper().database;
    // Query to join user information with each stored vector.
    final results = await db.rawQuery('''
    SELECT users.id as userId, users.nickname, users.name, users.relation, users.primary_image, user_vectors.vector 
    FROM users 
    JOIN user_vectors ON users.id = user_vectors.user_id
  ''');

    // Group the rows by user ID.
    Map<int, List<Map<String, dynamic>>> groupedResults = {};
    for (var row in results) {
      int userId = row['userId'] as int;
      if (groupedResults.containsKey(userId)) {
        groupedResults[userId]!.add(row);
      } else {
        groupedResults[userId] = [row];
      }
    }

    // Set your required matching settings.
    const double similarityThreshold = 0.5; // each sample must have cosine similarity above this to count
    const int requiredMatchCount = 3; // need at least three samples that match

    double bestScore = -1;
    Map<String, dynamic>? bestUser;

    // For each user, count matching samples.
    groupedResults.forEach((userId, rows) {
      int matchCount = 0;
      double similaritySum = 0;
      // Iterate over every stored vector (each row for that user).
      for (var row in rows) {
        // The stored vector is stored as JSON string.
        String vectorString = row['vector'] as String;
        // Parse the JSON list and ensure values are double.
        List<double> storedVector = (jsonDecode(vectorString) as List)
            .map((e) => (e is num ? e.toDouble() : 0.0))
            .toList();
        double sim = _dotProduct(queryVector, storedVector);
        if (sim >= similarityThreshold) {
          matchCount++;
          similaritySum += sim;
        }
      }
      // Only consider a user if at least the required number of samples match.
      if (matchCount >= requiredMatchCount) {
        double avgSim = similaritySum / matchCount;
        // We can weight the score by both the average similarity and the number of matching samples.
        double score = avgSim * matchCount;
        if (score > bestScore) {
          bestScore = score;
          bestUser = rows.first; // Use the user info from the first row.
        }
      }
    });

    print("🧠 Best user score: $bestScore");
    return bestUser;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0;
    double normA = 0;
    double normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    // Add a small constant to avoid division by zero.
    return dot / ((math.sqrt(normA) * math.sqrt(normB)) + 1e-10);
  }

  //ใช้ไม่ได้
  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += math.pow(a[i] - b[i], 2);
    }
    return math.sqrt(sum);
  }

//ใช้ไม่ได้
  double _manhattanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]).abs();
    }
    return sum;
  }

// 0.4 - 0.5 เวอร์จาด
  double _dotProduct(List<double> a, List<double> b) {
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

//ใช้ไม่ได้
  double hybridScore(List<double> a, List<double> b) {
    double cosine = _cosineSimilarity(a, b);
    double euclidean = _euclideanDistance(a, b);
    // For example, you might use: higher cosine similarity and lower Euclidean means a closer match.
    return (cosine * 0.7) - (euclidean * 0.3);
  }

  // Add these new functions to your CameraPage state

  // Function to open or create the history database.
  Future<Database> _getHistoryDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'facemind.db');

    Database db = await openDatabase(path, version: 2, onOpen: (db) {
      print("Database opened: $path");
    });

    await db.execute('''
    CREATE TABLE IF NOT EXISTS history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      matched_at TEXT,
      face_image BLOB
    )
  ''');

    return db;
  }

  Future<void> _checkHistoryDatabase() async {
    try {
      final db = await _getHistoryDatabase();
      final tableInfo = await db.rawQuery("PRAGMA table_info(history)");
      print("Table info for 'history': $tableInfo");

      final contents = await db.rawQuery("SELECT * FROM history");
      print("⏳⏳⏳Contents of 'history': $contents");
    } catch (e) {
      print("❌❌❌Error checking history database: $e");
    }
  }


  // Save a history record (user id and current time).
  Future<void> _saveHistory(int userId, Uint8List faceImageBytes) async {
    final db = await DatabaseHelper().database;
    DateTime now = DateTime.now();
    String nowFormatted = "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> existing = await db.rawQuery('''
    SELECT * FROM history
    WHERE user_id = ? 
      AND strftime('%Y-%m-%d %H:%M', matched_at) = ?
  ''', [userId, nowFormatted]);

    if (existing.isEmpty) {
      await db.insert(
        'history',
        {
          'user_id': userId,
          'matched_at': now.toIso8601String(),
          'face_image': faceImageBytes,
        },
      );
      print("History record saved for user $userId at $nowFormatted with face image blob.");
    } else {
      print("History record already exists for user $userId at $nowFormatted");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview with FacePainter overlay.
          Positioned.fill(child: _buildCameraPreview(context)),

          // Profile button (top-left)
          Positioned(
            top: 40,
            left: 20,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    );
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: _profileImageFile != null
                        ? FileImage(_profileImageFile!)
                        : null,
                    child: _profileImageFile == null
                        ? const Icon(Icons.person, color: Colors.blue)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "โปรไฟล์",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )

          ),

          // ปุ่มเบอร์ฉุกเฉิน (ขวาบน)
          Positioned(
            top: 40,
            right: 20,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
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
                  child: const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.phone, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "เบอร์ฉุกเฉิน",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_processedFaceImage != null)
            Positioned(
              top: 120,   // Adjust this vertical position as needed.
              right: 20,  // Adjust the horizontal position as needed.
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImage(imageBytes: _processedFaceImage!),
                    ),
                  );
                },
                child: Container(
                  width: 100,  // Set your desired width.
                  height: 100, // Set your desired height.
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Image.memory(
                    _processedFaceImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),


          // Flip camera button (top center) with text
          Positioned(
            top: 40,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.black),
                    onPressed: () {
                      setState(() {
                        _isFrontCamera = !_isFrontCamera;
                        _isCameraInitialized = false;
                      });
                      _initializeCamera();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "สลับกล้อง",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),


          // Bottom row with register, last image, map.
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ปุ่มลงทะเบียน (ล่างซ้าย)
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.how_to_reg, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "ลงทะเบียน",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // ปุ่มข้อมูลบุคคลแบบเดิม + เพิ่มข้อความใต้ปุ่ม
                Column(
                  children: [
                    FutureBuilder<String?>(
                      future: _lastImageFuture,
                      builder: (context, snapshot) {
                        Widget child;
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          child = Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        } else if (snapshot.hasData && snapshot.data != null) {
                          child = Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(snapshot.data!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        } else {
                          child = Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.white),
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
                          child: child,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "ข้อมูลบุคคล",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Map button.
                // ปุ่มแผนที่ (ล่างขวา)
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NavigationPage()),
                        );
                      },
                      child: const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.map, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "แผนที่",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),

          // ---------------------------------------------------------------------
          // BLACK BOX OVERLAY: Show matched user info (or placeholders "??")
          // ---------------------------------------------------------------------
          Positioned(
            bottom: 190,
            left: 50,
            right: 50,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ชื่อเล่น : ${_matchedUser?['nickname'] ?? "??"}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'ชื่อ : ${_matchedUser?['name'] ?? "??"}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'ความสัมพันธ์ : ${_matchedUser?['relation'] ?? "??"}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// FacePainter: Draws a red rectangle over each detected face.
/// Rotates each bounding box 90° clockwise (transformation: (x, y) => (y, originalWidth - x)).
/// For the front camera, the result is mirrored both horizontally and vertically.
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

  Rect _rotateRect90(Rect rect, Size originalSize) {
    double newLeft = rect.top;
    double newTop = originalSize.width - rect.right;
    double newRight = rect.bottom;
    double newBottom = originalSize.width - rect.left;
    return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

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

    double rotatedWidth = imageSize.height;
    double rotatedHeight = imageSize.width;
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

class FullScreenImage extends StatelessWidget {
  final Uint8List imageBytes;
  const FullScreenImage({Key? key, required this.imageBytes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Full Screen Image")),
      body: Center(
        child: Image.memory(imageBytes, fit: BoxFit.contain),
      ),
    );
  }
}
