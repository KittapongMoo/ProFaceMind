import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_place/google_place.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setphonenum.dart';

class Selectposition extends StatefulWidget {
  const Selectposition({super.key});

  @override
  _SelectpositionState createState() => _SelectpositionState();
}

class _SelectpositionState extends State<Selectposition> {
  GoogleMapController? mapController;
  LatLng? _selectedPosition;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  late GooglePlace googlePlace;
  List<AutocompletePrediction> predictions = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    googlePlace = GooglePlace("AIzaSyChd-Tfsm3EFmC8Jc5RXAj2Kg6r5pXojyU");
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog();
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedDialog();
      setState(() => _isLoading = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedPosition!, 15),
      );

      _getAddressFromLatLng(_selectedPosition!);
    } catch (e) {
      debugPrint("❌ ไม่สามารถดึงตำแหน่ง GPS ได้: $e");
      setState(() => _isLoading = false);
    }
  }

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

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        setState(() {
          _searchController.text = address;
        });
      }
    } catch (e) {
      debugPrint("❌ ไม่สามารถดึงที่อยู่จากพิกัดได้: $e");
    }
  }

  void _onSearchChanged(String value) async {
    if (value.isNotEmpty) {
      var result = await googlePlace.autocomplete.get(value);
      if (result != null && result.predictions != null) {
        setState(() {
          predictions = result.predictions!;
        });
      }
    } else {
      setState(() {
        predictions = [];
      });
    }
  }

  void _selectLocation(String placeId, String description) async {
    var details = await googlePlace.details.get(placeId);
    if (details != null && details.result != null) {
      double lat = details.result!.geometry!.location!.lat!;
      double lng = details.result!.geometry!.location!.lng!;
      setState(() {
        _selectedPosition = LatLng(lat, lng);
        _searchController.text = description;
        predictions = [];
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedPosition!, 15),
      );
    }
  }

  Future<void> _saveSelectedLocation() async {
    if (_selectedPosition != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('selected_latitude', _selectedPosition!.latitude);
      await prefs.setDouble('selected_longitude', _selectedPosition!.longitude);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SetPhoneNumber()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกตำแหน่งก่อน')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_selectedPosition != null)
            GoogleMap(
              onMapCreated: (controller) {
                mapController = controller;
                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedPosition!, 15),
                );
              },
              initialCameraPosition: CameraPosition(
                target: _selectedPosition!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('selected-location'),
                  position: _selectedPosition!,
                  infoWindow: const InfoWindow(title: "ตำแหน่งที่เลือก"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                )
              },
              onCameraMove: (position) {
                setState(() {
                  _selectedPosition = position.target;
                });
              },
              onCameraIdle: () {
                _getAddressFromLatLng(_selectedPosition!);
              },
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Search bar
          Positioned(
            top: 40,
            left: 16,
            right: 60,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  if (predictions.isNotEmpty) {
                    _selectLocation(predictions.first.placeId!, predictions.first.description!);
                  }
                },
                decoration: const InputDecoration(
                  hintText: "ค้นหาสถานที่",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  prefixIcon: Icon(Icons.search, color: Colors.blue),
                ),
              ),
            ),
          ),

          // Current location button (top right)
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              shape: const CircleBorder(),
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          // Suggestion List
          if (predictions.isNotEmpty)
            Positioned(
              top: 90,
              left: 16,
              right: 16,
              child: Material(
                elevation: 3,
                child: ListView.builder(
                  itemCount: predictions.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(predictions[index].description ?? ""),
                      onTap: () {
                        _selectLocation(
                          predictions[index].placeId!,
                          predictions[index].description!,
                        );
                      },
                    );
                  },
                ),
              ),
            ),

          // Floating panel with address + button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _searchController.text,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSelectedLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "เลือกที่นี่",
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
