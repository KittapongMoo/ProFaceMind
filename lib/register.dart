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
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
  bool _isDetectingFaces = false;
  List<Face> _faces = [];
  Uint8List? _croppedFace; // Store cropped face
  String? _capturedImagePath; // Store the captured image path

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
        ResolutionPreset.max, // Highest resolution for best preview
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;

      // Start real-time face detection.
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

  /// Face Detection Using ML Kit
  Future<void> _detectFaces(CameraImage image) async {
    try {
      final InputImage inputImage = _convertCameraImage(image);
      final List<Face> detectedFaces =
          await _faceDetector.processImage(inputImage);
      setState(() {
        _faces = detectedFaces;
      });
      if (detectedFaces.isNotEmpty) {
        _cropFace(image, detectedFaces.first);
      }
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

  /// Capture and Save Image
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

  /// Save Image to Mobile Gallery with Correct Orientation
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

      // Ensure correct orientation and flip for front camera
      img.Image orientedImage = img.bakeOrientation(capturedImage);
      if (_isFrontCamera) {
        orientedImage =
            img.flipHorizontal(orientedImage); // Flip for front camera
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

  /// Crop the detected face
  Future<void> _cropFace(CameraImage image, Face face) async {
    try {
      // Convert CameraImage YUV420 format to RGB img.Image format
      img.Image convertedImage = _convertYUV420ToImage(image);

      // Rotate according to sensor orientation
      final int sensorOrientation =
          _cameraController!.description.sensorOrientation;
      img.Image orientedImage;

      if (sensorOrientation == 90) {
        orientedImage = img.copyRotate(convertedImage, angle: 90);
      } else if (sensorOrientation == 270) {
        orientedImage = img.copyRotate(convertedImage, angle: -90);
      } else {
        orientedImage = convertedImage;
      }

      // Flip horizontally only for front camera
      if (_isFrontCamera) {
        orientedImage = img.flipHorizontal(orientedImage);
      }

      // MLKit bounding box relative to original preview dimensions
      final previewSize = _cameraController!.value.previewSize!;
      double scaleX = orientedImage.width / previewSize.height;
      double scaleY = orientedImage.height / previewSize.width;

      // Face bounding box
      Rect faceRect = face.boundingBox;

      int x = (faceRect.left * scaleX).round();
      int y = (faceRect.top * scaleY).round();
      int w = (faceRect.width * scaleX).round();
      int h = (faceRect.height * scaleY).round();

      // Boundary checking
      x = x.clamp(0, orientedImage.width - w);
      y = y.clamp(0, orientedImage.height - h);

      // Crop face region
      img.Image croppedFaceImage = img.copyCrop(
        orientedImage,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      Uint8List croppedBytes =
          Uint8List.fromList(img.encodeJpg(croppedFaceImage));

      setState(() {
        _croppedFace = croppedBytes;
      });

      print("Face cropped successfully");
    } catch (e) {
      print("Error cropping face: $e");
    }
  }

// Helper function to convert CameraImage to RGB Image (required)
  img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image rgbImage = img.Image(width: width, height: height);
    final plane = image.planes[0];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = (y ~/ 2) * image.planes[1].bytesPerRow + (x ~/ 2);

        final yp = plane.bytes[y * plane.bytesPerRow + x];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255).toInt();
        int g = (yp - up * 46549 / 131072 + 44 - vp * 731 / 1024 + 91)
            .clamp(0, 255)
            .toInt();
        int b = (yp + up * 1814 / 1024 - 227).clamp(0, 255).toInt();

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return rgbImage;
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Camera preview size reported in landscape
    final previewSize = _cameraController!.value.previewSize!;
    final double cameraAspectRatio = previewSize.width / previewSize.height;

    // Screen dimensions
    final Size screenSize = MediaQuery.of(context).size;
    final double screenAspectRatio = screenSize.width / screenSize.height;

    // Compute the base scale for covering the screen
    double scale = cameraAspectRatio / screenAspectRatio;

    // OPTIONAL: Adjust zoom manually (1.0 = default, <1.0 zoom out, >1.0 zoom in)
    double extraZoomFactor = 0.82;
    scale *= extraZoomFactor;

    // Determine rotation based on sensor orientation
    final int sensorOrientation =
        _cameraController!.description.sensorOrientation;
    double rotationAngle = 0;
    if (sensorOrientation == 90) {
      rotationAngle = math.pi / 2; // Rotate left for portrait
    } else if (sensorOrientation == 270) {
      rotationAngle = -math.pi / 2; // Rotate right for portrait
    }

    // Check if it's the front camera (to flip horizontally)
    final bool isFrontCamera = _cameraController!.description.lensDirection ==
        CameraLensDirection.front;

    // Build transform matrix for rotation & horizontal flip ONLY for front camera
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
          // Fullscreen camera preview (under all buttons).
          Positioned.fill(child: _buildCameraPreview()),
          // Face detection overlay.
          if (_isCameraInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: FacePainter(
                  _faces,
                  _cameraController!
                      .value.previewSize!, // <-- pass preview size
                  _isFrontCamera, // <-- pass front camera boolean
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
          // Display captured image.
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

      // Scale rectangle to match preview
      Rect scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      // Flip horizontally for front camera
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
