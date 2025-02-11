import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

class Selectpostition extends StatefulWidget {
  const Selectpostition({super.key});

  @override
  _SelectpostitionState createState() => _SelectpostitionState();
}

class _SelectpostitionState extends State<Selectpostition> {
  GoogleMapController? mapController;
  LatLng _selectedPosition = const LatLng(13.736717, 100.523186); // ค่าเริ่มต้น (กรุงเทพฯ)
  TextEditingController _locationController = TextEditingController();
  bool _locationFetched = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ✅ ดึงตำแหน่ง GPS ปัจจุบัน
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _locationFetched = true;
      });

      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLngZoom(_selectedPosition, 15));
      }

      _getAddressFromLatLng(_selectedPosition);
    } catch (e) {
      print("❌ ไม่สามารถดึงตำแหน่ง GPS ได้: $e");
    }
  }

  // ✅ ค้นหาที่อยู่จาก LatLng
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        setState(() {
          _locationController.text = address;
        });
      }
    } catch (e) {
      print("❌ ไม่สามารถดึงที่อยู่จากพิกัดได้: $e");
    }
  }

  // ✅ อัปเดตตำแหน่งเมื่อผู้ใช้เลือกจากแผนที่
  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedPosition = position;
    });

    _getAddressFromLatLng(position);
  }

  // ❗ แจ้งเตือนให้เปิด GPS
  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ต้องเปิด GPS"),
        content: const Text("กรุณาเปิด GPS เพื่อใช้งานแผนที่"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ปิด"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text("ไปที่ตั้งค่า"),
          ),
        ],
      ),
    );
  }

  // ❗ แจ้งเตือนเมื่อปฏิเสธสิทธิ์
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("สิทธิ์ถูกปฏิเสธ"),
        content: const Text("กรุณาให้สิทธิ์ตำแหน่งในตั้งค่าแอปเพื่อใช้งานฟีเจอร์นี้"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ปิด"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text("ไปที่ตั้งค่า"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
              if (_locationFetched) {
                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedPosition, 15),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('selected-location'),
                position: _selectedPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: _onMapTapped,
          ),

          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: "ค้นหาสถานที่",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _locationController,
                      googleAPIKey: "YOUR_GOOGLE_MAPS_API_KEY",
                      inputDecoration: InputDecoration(
                        hintText: "ค้นหาสถานที่",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      itemClick: (prediction) {
                        _locationController.text = prediction.description!;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_locationController.text, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _selectedPosition);
                    },
                    child: const Text("เลือกที่นี่"),
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
