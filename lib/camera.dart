import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras![_isFrontCamera ? 1 : 0],
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
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
              ? CameraPreview(_cameraController!)
              : const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.blue),
                onPressed: () {
                  // Navigate to personal information page
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
                  onPressed: () {
                    // Open gallery
                  },
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'map',
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.map),
                  onPressed: () {
                    // Navigate to map page
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
