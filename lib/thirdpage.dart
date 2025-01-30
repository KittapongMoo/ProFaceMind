import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ThirdPage extends StatefulWidget {
  const ThirdPage({super.key});

  @override
  _ThirdPageState createState() => _ThirdPageState();
}

class _ThirdPageState extends State<ThirdPage> {
  late GoogleMapController mapController;
  LatLng _currentPosition = const LatLng(13.736717, 100.523186); // ค่าเริ่มต้น (กรุงเทพฯ)
  bool _locationFetched = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // ฟังก์ชันตรวจสอบ GPS และขอตำแหน่ง
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      print("⚠️ GPS ปิด! ดึงตำแหน่งจาก IP แทน");
      _getLocationFromAPI();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print("🚫 ปฏิเสธการเข้าถึง GPS! ดึงตำแหน่งจาก IP แทน");
      _getLocationFromAPI();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print("📍 ตำแหน่ง GPS: ${position.latitude}, ${position.longitude}");

      _updatePosition(LatLng(position.latitude, position.longitude));
    } catch (e) {
      print("❌ ดึงตำแหน่ง GPS ไม่ได้: $e");
      _getLocationFromAPI();
    }
  }

  // ฟังก์ชันดึงพิกัดจาก API (ใช้แทน GPS)
  Future<void> _getLocationFromAPI() async {
    try {
      final response = await http.get(Uri.parse("https://ipapi.co/json/"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        double lat = data["latitude"];
        double lon = data["longitude"];
        print("🌍 ตำแหน่งจาก API: $lat, $lon");

        _updatePosition(LatLng(lat, lon));
      } else {
        print("❌ API ใช้ไม่ได้! ใช้ค่าพิกัดสำรอง");
        _updatePosition(const LatLng(13.736717, 100.523186));
      }
    } catch (e) {
      print("❌ เกิดข้อผิดพลาดกับ API: $e");
      _updatePosition(const LatLng(13.736717, 100.523186));
    }
  }

  // ฟังก์ชันอัปเดตตำแหน่งและเลื่อนกล้อง
  void _updatePosition(LatLng newPosition) {
    setState(() {
      _currentPosition = newPosition;
      _locationFetched = true;
    });

    if (mapController != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(newPosition, 15));
    }
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
                mapController.animateCamera(
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
            myLocationButtonEnabled: true,
          ),

          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pop(context);
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
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
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "ตั้งค่าที่อยู่ของคุณ",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "กรุณาระบุตำแหน่งที่คุณต้องการจะตั้งไว้เพื่อเป็นข้อมูลในการหาเส้นทางกลับของคุณ",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // เพิ่มฟังก์ชันเมื่อกดปุ่มนี้
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "ตั้งค่าเลย",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
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
