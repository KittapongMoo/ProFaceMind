import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // เพิ่มสำหรับ inputFormatters
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secondpage.dart';
import 'camera.dart';

class SetPhoneNumber extends StatefulWidget {
  const SetPhoneNumber({Key? key}) : super(key: key);

  @override
  _SetPhoneNumberState createState() => _SetPhoneNumberState();
}

class _SetPhoneNumberState extends State<SetPhoneNumber> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(13.736717, 100.523186); // ค่าเริ่มต้น
  bool _locationFetched = false;

  @override
  void initState() {
    super.initState();
    // 🗑️🔄️ Clear ข้อมูลผู้ใช้ให้เหมือนตอนเริ่มต้น
    // SharedPreferences.getInstance().then((prefs) => prefs.clear());
    _loadSavedData();
    _requestLocation();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('emergency_name') ?? '';
      _relationController.text = prefs.getString('emergency_relation') ?? '';
      _phoneController.text = prefs.getString('emergency_phone') ?? '';
    });
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergency_name', _nameController.text.trim());
      await prefs.setString('emergency_relation', _relationController.text.trim());
      await prefs.setString('emergency_phone', _phoneController.text.trim());

      await prefs.setBool('is_first_launch', false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลถูกบันทึกเรียบร้อยแล้ว!')),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _locationFetched = true;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 15),
        );
      }
    } catch (e) {
      debugPrint("❌ ไม่สามารถดึงตำแหน่ง GPS ได้: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (_locationFetched) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentPosition, 15),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('current-location'),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton(
              onPressed: () => Navigator.pop(context),
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ตั้งค่าเบอร์โทรศัพท์ฉุกเฉินของคุณ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'กรุณาใส่เบอร์โทรศัพท์บุคคลใกล้ชิดของคุณ\nที่สามารถติดต่อได้หากเกิดเหตุฉุกเฉิน',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    _buildRoundedField(
                      label: 'ชื่อ',
                      hint: 'กรุณาระบุชื่อ...',
                      controller: _nameController,
                    ),
                    _buildRoundedField(
                      label: 'ความสัมพันธ์',
                      hint: 'กรุณาระบุความสัมพันธ์...',
                      controller: _relationController,
                    ),
                    _buildRoundedField(
                      label: 'เบอร์โทร',
                      hint: 'กรอกเบอร์โทร...',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'เริ่มต้นการใช้งาน',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundedField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            autovalidateMode: AutovalidateMode.onUserInteraction, // 👈 Auto validate on user input
            inputFormatters: keyboardType == TextInputType.phone
                ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
                : [],
            onChanged: (_) {
              // 👇 Trigger rebuild and form validation
              if (_formKey.currentState != null) {
                _formKey.currentState!.validate();
              }
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอก$label';
              }
              if (keyboardType == TextInputType.phone && value.trim().length != 10) {
                return 'กรุณากรอกเบอร์โทรให้ครบ 10 หลัก';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey), // optional
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
