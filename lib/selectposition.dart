import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_place/google_place.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setphonenum.dart';

class Selectposition extends StatefulWidget {
  const Selectposition({Key? key}) : super(key: key);

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
    // Replace with your own API key.
    googlePlace = GooglePlace("YOUR API");
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
      debugPrint("❌ Unable to retrieve GPS position: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Please enable GPS"),
        content: const Text("Enable GPS to use the map feature"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Denied"),
        content: const Text(
            "Please grant location permission in app settings to use this feature"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text("Settings"),
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
        String address =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        setState(() {
          _searchController.text = address;
        });
      }
    } catch (e) {
      debugPrint("❌ Unable to retrieve address: $e");
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
        const SnackBar(content: Text('Please select a location first')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
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
                  infoWindow: const InfoWindow(title: "Selected Position"),
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

          // Search Bar
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
                    _selectLocation(
                      predictions.first.placeId!,
                      predictions.first.description!,
                    );
                  }
                },
                decoration: const InputDecoration(
                  hintText: "โปรดระบุสถานที่...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  prefixIcon: Icon(Icons.search, color: Colors.blue),
                ),
              ),
            ),
          ),

          // Current Location Button (top right)
          Positioned(
            top: 40,
            right: 5,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              shape: const CircleBorder(),
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          // Prediction List using the same left/right margins as the search box
          if (predictions.isNotEmpty)
            Positioned(
              top: 95,
              left: 16,
              right: 60,
              child: AnimatedOpacity(
                opacity: predictions.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: predictions.length,
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        return PredictionTile(
                          prediction: predictions[index],
                          onTap: _selectLocation,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // Floating Panel with Address and Select Button
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

// Custom widget for Prediction Tile
class PredictionTile extends StatelessWidget {
  final AutocompletePrediction prediction;
  final Function(String, String) onTap;

  const PredictionTile({
    Key? key,
    required this.prediction,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.blueAccent),
        title: Text(
          prediction.description ?? "",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onTap: () {
          onTap(prediction.placeId!, prediction.description!);
        },
      ),
    );
  }
}
