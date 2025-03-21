import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navigation.dart';
import 'profile.dart';
import 'register.dart'; // ✅ Ensure RegisterPage is imported

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

  @override
  void initState() {
    super.initState();

    // Lock the app orientation to portrait only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        CameraDescription selectedCamera = _cameras![_isFrontCamera ? 1 : 0];

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (!mounted) return;

        // Lock preview to portrait mode
        await _cameraController!
            .lockCaptureOrientation(DeviceOrientation.portraitUp);

        setState(() {
          _isCameraInitialized = true;
          _sensorOrientation = selectedCamera.sensorOrientation;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _takePicture() async {
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

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องอนุญาตให้เข้าถึงรูปภาพก่อน')),
      );
      return;
    }

    try {
      final pickedFile =
      await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _galleryImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  double _calculateRotation() {
    if (_sensorOrientation == 90) return 1.5708; // 90 degrees in radians
    if (_sensorOrientation == 270) return -1.5708; // -90 degrees in radians
    return 0; // Default no rotation
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _isCameraInitialized
                ? Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.previewSize!.height /
                    _cameraController!.value.previewSize!.width,
                child: Transform.rotate(
                  angle: _calculateRotation(), // Fix rotation based on sensor
                  child: Transform(
                    alignment: Alignment.center,
                    transform: _isFrontCamera
                        ? Matrix4.rotationY(3.1415927) // Mirror front cam
                        : Matrix4.identity(),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Profile button
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
                    MaterialPageRoute(
                        builder: (context) => const ProfilePage()),
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.red,
              child: IconButton(
                icon: const Icon(Icons.phone, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("เบอร์โทรศัพท์ฉุกเฉิน"),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("นายสมพร (ลูกชาย)"),
                          Text("093 - 478 - 9323",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("ปิด"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            bottom: 80,
            left: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'flipCamera',
                  backgroundColor: Colors.grey,
                  child: const Icon(Icons.flip_camera_ios),
                  onPressed: _switchCamera,
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'register',
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.how_to_reg),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'map',
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.map),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NavigationPage()),
                    );
                  },
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 30,
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
