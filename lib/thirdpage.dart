import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ThirdPage extends StatefulWidget {
  const ThirdPage({super.key});

  @override
  _ThirdPageState createState() => _ThirdPageState();
}

class _ThirdPageState extends State<ThirdPage> {
  late GoogleMapController mapController;
  LatLng _currentPosition = const LatLng(13.736717, 100.523186); // ค่าเริ่มต้น (กรุงเทพฯ)
  bool _locationFetched = false; // ตรวจสอบว่าดึงตำแหน่งแล้วหรือยัง

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // ฟังก์ชันตรวจสอบการอนุญาตและดึงตำแหน่งปัจจุบัน
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // ตรวจสอบว่าบริการ GPS เปิดอยู่หรือไม่
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // แจ้งเตือนให้เปิด GPS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเปิด GPS เพื่อใช้ฟีเจอร์นี้")),
      );
      return;
    }

    // ขออนุญาตเข้าถึงตำแหน่ง
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("การเข้าถึงตำแหน่งถูกปฏิเสธ")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("การเข้าถึงตำแหน่งถูกปฏิเสธถาวร กรุณาเปิดสิทธิ์ในการตั้งค่า")),
      );
      return;
    }

    // ดึงตำแหน่งปัจจุบัน
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _locationFetched = true;

      // ย้ายกล้องไปยังตำแหน่งปัจจุบัน
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 15),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map Widget
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
            myLocationEnabled: true, // เปิดไอคอนแสดงตำแหน่งปัจจุบัน
            myLocationButtonEnabled: true, // ปุ่มให้ผู้ใช้กดเพื่อกลับไปยังตำแหน่งของตน
          ),

          // ปุ่มย้อนกลับที่มุมซ้ายบน
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pop(context); // กลับไปหน้าก่อนหน้า
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          // UI ด้านล่างของแผนที่
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
                  // Indicator จุด 3 จุด
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                          (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == 1 ? Colors.blue : Colors.blue[100], // จุดตรงกลางเป็นสีเข้ม
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // หัวข้อ
                  const Text(
                    "ตั้งค่าที่อยู่ของคุณ",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),

                  // คำอธิบาย
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "กรุณาระบุตำแหน่งที่คุณต้องการจะตั้งไว้เพื่อเป็นข้อมูลในการหาเส้นทางกลับของคุณ",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ปุ่ม "ตั้งค่าเลย"
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
