import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
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
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:facemind/main.dart';
import 'package:facemind/database_helper.dart';
import 'package:exif/exif.dart';

import 'fillinfo.dart'; // Make sure FillInfoPage({required this.userId}) is defined

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
      performanceMode: FaceDetectorMode.accurate,
      enableTracking: true,
    ),
  );
  bool _isDetectingFaces = false;
  List<Face> _faces = [];
  bool _processingImage = false;

  // List to store the face vectors (each from one image)
  List<List<double>> _faceVectors = [];

  // List to store the full (uncropped) image paths.
  List<String> fullImagePaths = [];

  // ImagePicker for gallery selection.
  final ImagePicker _picker = ImagePicker();

  // New state variable to hold the processed face image bytes for preview.
  Uint8List? _processedFaceImage;

  Uint8List _imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        int pixel = image.getPixel(x, y);
        double r = img.getRed(pixel).toDouble();
        double g = img.getGreen(pixel).toDouble();
        double b = img.getBlue(pixel).toDouble();
        convertedBytes[pixelIndex++] = (r - 127.5) / 128.0;
        convertedBytes[pixelIndex++] = (g - 127.5) / 128.0;
        convertedBytes[pixelIndex++] = (b - 127.5) / 128.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final int ySize = image.planes[0].bytes.length;
      final int uvSize = image.planes[1].bytes.length + image.planes[2].bytes.length;
      final Uint8List nv21 = Uint8List(ySize + uvSize);
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
          nv21[offset++] = image.planes[1].bytes[rowOffset1 + col * uvPixelStride];
          nv21[offset++] = image.planes[2].bytes[rowOffset2 + col * uvPixelStride];
        }
      }
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final imageRotation = _getInputImageRotation(camera.sensorOrientation);
      if (imageRotation == null) return null;
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
    _loadModel();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  Interpreter? interpreter;

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
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      print("Camera permission denied");
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        int backCameraIndex = _cameras!.indexWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back);
        await _setCamera(backCameraIndex != -1 ? backCameraIndex : 0);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
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

  Future<void> _setCamera(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;
    final oldController = _cameraController;
    _cameraController = null;
    setState(() {}); // Show loading
    if (oldController != null) {
      await oldController.dispose();
    }
    try {
      final selectedCamera = _cameras![cameraIndex];
      final newController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await newController.initialize();
      newController.startImageStream((CameraImage cameraImage) {
        _detectFacesFromCamera(cameraImage);
      });
      if (!mounted) return;
      setState(() {
        _cameraController = newController;
        _isCameraInitialized = true;
        _isFrontCamera = selectedCamera.lensDirection == CameraLensDirection.front;
      });
    } catch (e) {
      print('Error setting camera: $e');
    }
  }

  Future<bool> _validateFace(File imageFile) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (e) {
      print('Error validating face: $e');
      return false;
    }
  }

  void _showErrorPopup(String message) {
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

  void _hideDialog() {
    if (navigatorKey.currentContext != null &&
        Navigator.of(navigatorKey.currentContext!).canPop()) {
      Navigator.of(navigatorKey.currentContext!).pop();
    }
  }

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
      await _cameraController!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 500));
      final XFile imageFile = await _cameraController!.takePicture();
      print("Picture taken: ${imageFile.path}");
      await _processCapturedImage(File(imageFile.path));
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

  /// Process the captured/selected image:
  /// 1. Save a copy of the original full image.
  /// 2. Detect faces and process for recognition (for preview purposes).
  /// 3. Add face vector (for count) and store full image path.
  Future<void> _processCapturedImage(File imageFile) async {
    try {
      // 0) Save a copy of the original image for later display.
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory fullImageDir = Directory('${appDir.path}/full_faces');
      if (!fullImageDir.existsSync()) {
        fullImageDir.createSync(recursive: true);
      }
      String fullImagePath = join(fullImageDir.path, basename(imageFile.path));
      await imageFile.copy(fullImagePath);
      fullImagePaths.add(fullImagePath);

      // 1) Detect faces using the file.
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      _hideDialog();
      if (faces.isEmpty) {
        _showErrorPopup("No face detected in this image");
        return;
      }

      // 2) Load and decode the image.
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? fullImage = img.decodeImage(imageBytes);
      if (fullImage == null) {
        _showErrorPopup("Failed to decode image");
        return;
      }

      // 3) Read EXIF orientation data.
      final Map<String, IfdTag> exifData = await readExifFromBytes(imageBytes);
      int rotationAngle = 0;
      if (!_isFrontCamera) {
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
        rotationAngle = -90;
      }

      // 4) Rotate the full image.
      final img.Image orientedImage = (rotationAngle != 0)
          ? img.copyRotate(fullImage, rotationAngle)
          : fullImage;

      // 5) Get bounding box from the first detected face.
      final Face face = faces.first;
      Rect box = face.boundingBox;

      // 6) If front camera, mirror the bounding box.
      if (_isFrontCamera) {
        box = Rect.fromLTRB(
          orientedImage.width - box.right,
          box.top,
          orientedImage.width - box.left,
          box.bottom,
        );
      }

      // 7) Add margin and ensure crop rectangle is within bounds.
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

      // 8) Crop and resize the face for preview.
      final img.Image croppedFace = img.copyCrop(orientedImage, x, y, w, h);
      final img.Image resizedFace = img.copyResize(croppedFace, width: 112, height: 112);
      _processedFaceImage = Uint8List.fromList(img.encodeJpg(resizedFace));
      setState(() {});

      // 9) Preprocess and run face recognition (used only for count).
      final Uint8List processedBytes = _imageToByteListFloat32(resizedFace, 112, 127.5, 128.0);
      List<double> vector = await _runFaceRecognition(processedBytes);
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

      // 10) When 5 images have been captured, register the user.
      if (_faceVectors.length >= 5) {
        await _registerUserWithImages(fullImagePaths);
      }
    } catch (e) {
      _hideDialog();
      print('❌ Error processing image: $e');
      _showErrorPopup("Error processing image: $e");
    }
  }

  /// Modified registration function that does not compute an average vector.
  /// It registers the user with an empty face_vector and saves the 5 full images.
  Future<void> _registerUserWithImages(List<String> fullImagePaths) async {
    try {
      _showProgressIndicator("Registering user...");
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      final db = await DatabaseHelper().database;
      final Directory appDir = await getApplicationDocumentsDirectory();

      // Insert user with empty face_vector.
      int userId = await db.insert('users', {
        'face_vector': '',
        'nickname': '',
        'name': '',
        'relation': '',
        'primary_image': '', // will update later
      });

      // Create a final directory for the user images.
      final Directory finalUserDir = Directory('${appDir.path}/user_$userId');
      if (!finalUserDir.existsSync()) {
        finalUserDir.createSync(recursive: true);
      }

      List<String> finalImagePaths = [];
      for (var path in fullImagePaths) {
        String newFilePath = join(finalUserDir.path, basename(path));
        File newFile = await File(path).copy(newFilePath);
        finalImagePaths.add(newFile.path);
        await db.insert('user_images', {
          'user_id': userId,
          'image_path': newFile.path,
        });
        // Delete the temporary file.
        File(path).deleteSync();
      }

      // Update primary_image with the first saved full image.
      if (finalImagePaths.isNotEmpty) {
        await db.update(
          'users',
          {'primary_image': finalImagePaths.first},
          where: 'id = ?',
          whereArgs: [userId],
        );
      }

      // Clear stored vectors and image paths.
      _faceVectors.clear();
      fullImagePaths.clear();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildCameraPreview(context)),
          if (_processedFaceImage != null)
            Positioned(
              bottom: 120,
              left: 20,
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
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Image.memory(_processedFaceImage!, fit: BoxFit.cover),
                ),
              ),
            ),
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
              child: const Text(
                "กรุณาลงทะเบียนใบหน้าของคุณผ่านการถ่ายรูปใบหน้าของคุณในมุมที่แตกต่างกัน",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 20,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _switchCamera,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 2)],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.flip_camera_ios, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 4),
                const Text("สลับกล้อง", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _processingImage ? null : _takePicture,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 2)],
                    ),
                    child: Center(
                      child: _processingImage
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text("ถ่ายภาพ", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            right: 20,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _processingImage ? null : _pickImage,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 2)],
                    ),
                    child: const Center(child: Icon(Icons.photo_library, color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 4),
                const Text("เลือกรูป", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Positioned(
            top: 120,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Text("จำนวนรูป: ${_faceVectors.length}/5", style: const TextStyle(color: Colors.white)),
                  const SizedBox(width: 5),
                  _faceVectors.length >= 5
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : const Icon(Icons.circle_outlined, color: Colors.white, size: 20),
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
    final previewSize = _cameraController!.value.previewSize!;
    final double cameraAspectRatio = previewSize.width / previewSize.height;
    final Size screenSize = MediaQuery.of(buildContext).size;
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
      body: Center(child: Image.memory(imageBytes, fit: BoxFit.contain)),
    );
  }
}