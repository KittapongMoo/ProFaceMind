import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  late Marker _destinationMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDestinationPosition();
  }

  /// 📍 ดึงตำแหน่งปัจจุบัน
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

      // 📍 เพิ่ม Marker สำหรับตำแหน่งปัจจุบันพร้อม InfoWindow
      _markers.add(Marker(
        markerId: const MarkerId('currentLocation'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '📍 ตำแหน่งปัจจุบันของคุณ'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    });
  }

  /// 📍 โหลดตำแหน่งจุดหมายจาก SharedPreferences
  Future<void> _loadDestinationPosition() async {
    final prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('selected_latitude');
    double? lng = prefs.getDouble('selected_longitude');

    if (lat != null && lng != null) {
      _destinationPosition = LatLng(lat, lng);

      // 📍 เพิ่ม Marker สำหรับจุดหมายปลายทางพร้อม InfoWindow
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: _destinationPosition!,
        infoWindow: const InfoWindow(title: '🏠 บ้านของคุณ'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      setState(() {
        _markers.add(_destinationMarker);
      });

      // 📍 โฟกัสกล้องไปที่ตำแหน่งบ้านของคุณทันที
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(_destinationPosition!, 16));

      // ✅ เปิด InfoWindow ของหมุดจุดหมายทันที
      controller.showMarkerInfoWindow(const MarkerId('destination'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ ไม่พบตำแหน่งปลายทาง')),
      );
    }
  }

  /// 🚗 เปิด Google Maps เพื่อเริ่มนำทาง
  Future<void> _launchGoogleMapsNavigation() async {
    if (_currentPosition == null || _destinationPosition == null) return;

    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=${_destinationPosition!.latitude},${_destinationPosition!.longitude}&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } else {
      throw 'ไม่สามารถเปิด Google Maps ได้';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('นำทางด้วย Google Maps')),
      body: _destinationPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _destinationPosition!,
              zoom: 16,
            ),
            onMapCreated: (GoogleMapController controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);

                // ✅ เปิด InfoWindow ของหมุดจุดหมายเมื่อสร้างแผนที่เสร็จ
                controller.showMarkerInfoWindow(const MarkerId('destination'));
              }
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
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
                'เริ่มนำทาง',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
