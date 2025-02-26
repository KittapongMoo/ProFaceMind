import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navigation.dart'; // ✅ Import หน้า navigation.dart
import 'profile.dart'; // ✅ Import หน้า profile.dart

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  bool _isFrontCamera = false;
  File? _galleryImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  int _sensorOrientation = 0;

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      CameraDescription selectedCamera = _cameras![_isFrontCamera ? 1 : 0];

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      _sensorOrientation = selectedCamera.sensorOrientation;

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
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
    });
    await _initializeCamera();
  }

  void _showEmergencyContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("เบอร์โทรศัพท์ฉุกเฉิน"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("นายสมพร (ลูกชาย)"),
            Text("093 - 478 - 9323", style: TextStyle(fontWeight: FontWeight.bold)),
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
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
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
    if (_isFrontCamera) {
      if (_sensorOrientation == 90) return 90 * (3.1415927 / 180);
      if (_sensorOrientation == 270) return -90 * (3.1415927 / 180);
      if (_sensorOrientation == 180) return 180 * (3.1415927 / 180);
    } else {
      if (_sensorOrientation == 90) return 90 * (3.1415927 / 180);
      if (_sensorOrientation == 270) return -90 * (3.1415927 / 180);
    }
    return 0.0;
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
          _isCameraInitialized
              ? Positioned.fill(
            child: ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.height * 0.01,
                    height: MediaQuery.of(context).size.width * 0.02,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..rotateZ(_calculateRotation())
                        ..scale(_isFrontCamera ? 1.0 : 1.0, 1.0),
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              ),
            ),
          )
              : const Center(child: CircularProgressIndicator()),

          // ✅ เพิ่มปุ่มเปิดหน้าโปรไฟล์
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.blue),
                onPressed: () {
                  // ✅ นำทางไปหน้า ProfilePage
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
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
                onPressed: _showEmergencyContact,
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
                  heroTag: 'gallery',
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.photo_library),
                  onPressed: _pickImage,
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'map',
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.map),
                  onPressed: () {
                    // ✅ นำทางไปยังหน้า navigation.dart
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NavigationPage()),
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