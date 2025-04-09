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
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:facemind/main.dart';
import 'package:facemind/database_helper.dart';

import 'fillinfo.dart'; // Make sure FillInfoPage({required this.userId}) is defined

/// Make sure you set this in main.dart:
/// MaterialApp(navigatorKey: navigatorKey, home: RegisterPage())
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      performanceMode:
          FaceDetectorMode.accurate, // accurate for better detection
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

  Uint8List _imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    // Create a buffer for 1 image, of shape (inputSize, inputSize, 3)
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        int pixel = image.getPixel(x, y);
        double r = img.getRed(pixel).toDouble();
        double g = img.getGreen(pixel).toDouble();
        double b = img.getBlue(pixel).toDouble();
        // Normalize the pixel values.
        convertedBytes[pixelIndex++] = (r - 127.5) / 128.0;
        convertedBytes[pixelIndex++] = (g - 127.5) / 128.0;
        convertedBytes[pixelIndex++] = (b - 127.5) / 128.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  // Improved conversion function for camera images
  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      // Convert YUV420 to NV21.
      // Calculate the size of the Y plane.
      final int ySize = image.planes[0].bytes.length;
      // The U and V planes.
      final int uvSize =
          image.planes[1].bytes.length + image.planes[2].bytes.length;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      // Copy the Y plane as-is.
      nv21.setRange(0, ySize, image.planes[0].bytes);

      // Many devices provide U and V in separate planes.
      // NV21 requires that the chroma components are interleaved as V then U.
      // Note: Some devices may swap U and V; you might need to adjust if you see color issues.
      int offset = ySize;
      final int uvPixelStride = image.planes[1].bytesPerPixel!; // normally 2
      final int uvRowStride = image.planes[1].bytesPerRow;
      // The height and width for the UV planes.
      final int uvHeight = image.height ~/ 2;
      final int uvWidth = image.width ~/ 2;

      for (int row = 0; row < uvHeight; row++) {
        final int rowOffset1 = row * image.planes[1].bytesPerRow;
        final int rowOffset2 = row * image.planes[2].bytesPerRow;
        for (int col = 0; col < uvWidth; col++) {
          // In NV21 the order is V then U.
          nv21[offset++] =
              image.planes[1].bytes[rowOffset1 + col * uvPixelStride];
          nv21[offset++] =
              image.planes[2].bytes[rowOffset2 + col * uvPixelStride];
        }
      }

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final imageRotation = _getInputImageRotation(camera.sensorOrientation);
      if (imageRotation == null) return null;

      // Create metadata explicitly using NV21.
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        // We set the format explicitly to NV21.
        format: InputImageFormat.nv21,
        // For NV21, the bytesPerRow can be taken from the Y plane.
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: metadata,
      );
    } catch (e) {
      print("Error converting camera image: $e");
      return null;
    }
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
    _loadModel(); // Call the new function correctly
  }

  @override
  void dispose() {
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  Interpreter? interpreter;

  /// Load MobileFaceNet Model via TFLite
  Future<void> _loadModel() async {
    try {
      // Explicitly load asset data first
      final modelData = await rootBundle.load('assets/MobileFaceNet.tflite');
      final buffer = modelData.buffer;

      interpreter = Interpreter.fromBuffer(buffer.asUint8List());
      print('✅ TFLite model loaded successfully from buffer!');
    } catch (e) {
      print('❌ Error loading model: $e');
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
        int backCameraIndex  = _cameras!.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back);
        await _setCamera(backCameraIndex  != -1 ? backCameraIndex  : 0);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  /// Switch Between Front and Back Cameras
  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    // Update the camera flag
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });

    // Find the camera index that matches the new lens direction.
    int cameraIndex = 0;
    for (int i = 0; i < _cameras!.length; i++) {
      if ((_isFrontCamera &&
          _cameras![i].lensDirection == CameraLensDirection.front) ||
          (!_isFrontCamera &&
              _cameras![i].lensDirection == CameraLensDirection.back)) {
        cameraIndex = i;
        break;
      }
    }
    // Dispose of the current controller and set up the new one.
    await _setCamera(cameraIndex);
  }

  Future<void> _detectFacesFromCamera(CameraImage cameraImage) async {
    if (_isDetectingFaces) return;
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

  /// Set Camera by Index
  Future<void> _setCamera(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    // 1) Temporarily store the old controller and set our field to null
    final oldController = _cameraController;
    _cameraController = null;
    setState(() {}); // Forces a rebuild, which will show a loading indicator

    // 2) Dispose the old controller safely
    if (oldController != null) {
      await oldController.dispose();
    }

    // 3) Create and initialize the new controller
    try {
      final selectedCamera = _cameras![cameraIndex];
      final newController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await newController.initialize();

      // 4) Start the image stream
      newController.startImageStream((CameraImage cameraImage) {
        _detectFacesFromCamera(cameraImage);
      });

      // 5) Update our state with the new controller
      if (!mounted) return;
      setState(() {
        _cameraController = newController;
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
      // Use fromFilePath so that the EXIF rotation is handled.
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
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

      // Stop the image stream before taking a picture.
      await _cameraController!.stopImageStream();

      // Wait longer to ensure the image stream has fully stopped.
      await Future.delayed(const Duration(milliseconds: 500));

      // Capture the picture.
      final XFile imageFile = await _cameraController!.takePicture();
      print("Picture taken: ${imageFile.path}");

      // Process the captured image.
      await _processCapturedImage(File(imageFile.path));

      // Restart the image stream.
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
      final XFile? imageFile =
          await _picker.pickImage(source: ImageSource.gallery);
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
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      _hideDialog();

      if (faces.isEmpty) {
        _showErrorPopup("No face detected in this image");
        return;
      }

      // Load and decode the image
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? fullImage = img.decodeImage(imageBytes);
      if (fullImage == null) {
        _showErrorPopup("Failed to decode image");
        return;
      }

      // Use the first detected face
      final Face face = faces.first;
      final Rect box = face.boundingBox;

      // Crop the face (add margin for better performance)
      int x = math.max(0, box.left.toInt() - 20);
      int y = math.max(0, box.top.toInt() - 20);
      int w = math.min(fullImage.width - x, box.width.toInt() + 40);
      int h = math.min(fullImage.height - y, box.height.toInt() + 40);
      final img.Image croppedFace = img.copyCrop(fullImage, x, y, w, h);

      // Resize to 112x112
      final img.Image resizedFace = img.copyResize(croppedFace, width: 112, height: 112);

      // Preprocess
      final Uint8List processedBytes = _imageToByteListFloat32(resizedFace, 112, 127.5, 128.0);

      // Run recognition
      List<double> vector = await _runFaceRecognition(processedBytes);

      // Normalize the vector (L2 norm)
      final double norm = math.sqrt(vector.fold(0, (sum, val) => sum + val * val));
      if (norm > 0) {
        vector = vector.map((e) => e / norm).toList();
      }

      if (vector.every((v) => v == 0)) {
        _showErrorPopup("Face recognition failed. Try again.");
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
      _hideDialog();
      print('❌ Error processing image: $e');
      _showErrorPopup("Error processing image: $e");
    }
  }

  Future<void> _registerUserWithImages() async {
    try {
      _showProgressIndicator("Registering user...");

      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      final db = await DatabaseHelper().database;
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory userDir = Directory('${appDir.path}/temp_faces');

      if (!userDir.existsSync()) {
        userDir.createSync(recursive: true);
      }

      // Additionally, ensure at least a placeholder or initial setup
      if (userDir.listSync().isEmpty) {
        print("⚠️ Warning: temp_faces directory is empty. Ensure you're saving images to this directory after capturing.");
      }



      // Fetch current session images
      final List<FileSystemEntity> imagesList = userDir.listSync().whereType<File>().toList();
      imagesList.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      // Calculate the average vector (optional, you can store or skip it)
      List<double> averageVector = List.filled(128, 0.0);
      for (var vector in _faceVectors) {
        for (int i = 0; i < 128; i++) {
          averageVector[i] += vector[i];
        }
      }
      averageVector = averageVector.map((val) => val / _faceVectors.length).toList();

      // Insert user to get userId
      int userId = await db.insert('users', {
        'face_vector': jsonEncode(averageVector),  // Optional
        'nickname': '',
        'name': '',
        'relation': '',
        'primary_image': '', // to update later
      });

      // ✅ Insert each of the 5 vectors into user_vectors table
      for (var vector in _faceVectors) {
        await db.insert('user_vectors', {
          'user_id': userId,
          'vector': jsonEncode(vector),
        });
      }

      // Move images to final user directory
      final Directory finalUserDir = Directory('${appDir.path}/user_$userId');
      if (!finalUserDir.existsSync()) {
        finalUserDir.createSync(recursive: true);
      }

      List<String> finalImagePaths = [];
      for (var imageFile in imagesList) {
        String newFilePath = join(finalUserDir.path, basename(imageFile.path));
        File newFile = await File(imageFile.path).copy(newFilePath);
        finalImagePaths.add(newFile.path);
        await db.insert('user_images', {
          'user_id': userId,
          'image_path': newFile.path,
        });
        imageFile.deleteSync();
      }

      // Update primary_image
      if (finalImagePaths.isNotEmpty) {
        await db.update(
          'users',
          {'primary_image': finalImagePaths.first},
          where: 'id = ?',
          whereArgs: [userId],
        );
      }

      _faceVectors.clear();

      print("✅ User registered with id: $userId");
      _hideDialog();

      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pushReplacement(
          MaterialPageRoute(
            builder: (_) => FillInfoPage(userId: userId),
          ),
        );
      } else {
        print('❌ Navigation failed: navigatorKey context is null');
      }
    } catch (e) {
      _hideDialog();
      print('❌ Error registering user: $e');
      _showErrorPopup("Error registering user: $e");
    }
  }

  /// Run face recognition using tflite_flutter
  Future<List<double>> _runFaceRecognition(Uint8List imageBytes) async {
    if (interpreter == null) {
      print("Interpreter not initialized");
      return List.filled(128, 0.0);
    }

    try {
      // Input and output buffer definition
      var input = imageBytes.buffer.asFloat32List().reshape([1, 112, 112, 3]);
      var output = List.filled(1 * 128, 0).reshape([1, 128]);

      interpreter!.run(input, output);

      return List<double>.from(output[0]);
    } catch (e) {
      print("Error running face recognition: $e");
      return List.filled(128, 0.0);
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
                      : Icon(Icons.circle_outlined,
                          color: Colors.white, size: 20),
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
    double extraZoomFactor = 0.72;
    // First multiply the scale by 0.82
    scale *= extraZoomFactor;

    // Determine rotation based on sensor orientation
    final int sensorOrientation =
        _cameraController!.description.sensorOrientation;
    double rotationAngle = 0;
    if (sensorOrientation == 90) {
      rotationAngle = math.pi / 2;
    } else if (sensorOrientation == 270) {
      rotationAngle = -math.pi / 2;
    }

    // Check if it is front camera to mirror horizontally
    final bool isFrontCamera = _cameraController!.description.lensDirection ==
        CameraLensDirection.front;

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

  /// Rotates a rectangle 90° clockwise.
  /// Transformation: (x, y) => (y, originalWidth - x)
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

    // After a 90° clockwise rotation, the effective dimensions swap:
    // rotatedWidth is the original image height, and rotatedHeight is the original image width.
    double rotatedWidth = imageSize.height;
    double rotatedHeight = imageSize.width;

    // Scale factors to map the rotated coordinates to the canvas.
    final double scaleX = size.width / rotatedWidth;
    final double scaleY = size.height / rotatedHeight;

    for (var face in faces) {
      // Rotate the original bounding box.
      Rect rotatedRect = _rotateRect90(face.boundingBox, imageSize);

      // For the front camera, mirror both horizontally and vertically.
      if (isFrontCamera) {
        rotatedRect = _mirrorRectBoth(rotatedRect, rotatedWidth, rotatedHeight);
      }

      // Scale the rotated (and mirrored) rectangle to the canvas dimensions.
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



