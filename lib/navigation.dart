import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  Completer<GoogleMapController> _mapController = Completer();
  LatLng? _currentPosition;
  LatLng? _destinationPosition;

  Set<Marker> _markers = {};
  String destinationAddress = "กำลังโหลดที่อยู่...";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDestinationPosition();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);

      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: '📍 ตำแหน่งปัจจุบันของคุณ'),
        ),
      );
    });
  }

  Future<void> _loadDestinationPosition() async {
    final prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('selected_latitude');
    double? lng = prefs.getDouble('selected_longitude');

    if (lat != null && lng != null) {
      _destinationPosition = LatLng(lat, lng);

      // ✅ ใช้ reverse geocoding เพื่อดึงที่อยู่จริง
      destinationAddress = await _getAddressFromLatLng(lat, lng);

      final marker = Marker(
        markerId: const MarkerId('destination'),
        position: _destinationPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: '🏠 บ้านของคุณ'),
      );

      setState(() {
        _markers.add(marker);
      });

      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_destinationPosition!, 16),
      );
      controller.showMarkerInfoWindow(const MarkerId('destination'));

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ ไม่พบตำแหน่งปลายทาง')),
      );
    }
  }

  /// 📍 แปลงพิกัดเป็นที่อยู่ (reverse geocoding)
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street ?? ''} ${place.subLocality ?? ''} ${place.locality ?? ''} ${place.administrativeArea ?? ''} ${place.postalCode ?? ''}'.trim();
      }
      return 'ไม่พบที่อยู่';
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      return 'ไม่สามารถดึงที่อยู่ได้';
    }
  }

  Future<void> _launchGoogleMapsNavigation() async {
    if (_currentPosition == null || _destinationPosition == null) return;

    final String url =
        'https://www.google.com/maps/dir/?api=1&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=${_destinationPosition!.latitude},${_destinationPosition!.longitude}&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'ไม่สามารถเปิด Google Maps ได้';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ แผนที่ Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _destinationPosition ?? const LatLng(13.736717, 100.523186),
              zoom: 16,
            ),
            onMapCreated: (GoogleMapController controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          // 🔙 ปุ่มย้อนกลับ (มุมซ้ายบน)
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

          // 🧭 ปุ่มกลับไปยังตำแหน่งปัจจุบัน (มุมขวาบน)
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: () async {
                if (_currentPosition != null) {
                  final controller = await _mapController.future;
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentPosition!, 16),
                  );
                  controller.showMarkerInfoWindow(
                    const MarkerId('currentLocation'),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          // 🔽 กล่องล่างแสดงที่อยู่บ้าน
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'จุดหมายปลายทาง :',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    destinationAddress,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _launchGoogleMapsNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'นำทางเลย',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
