import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Selectpostition extends StatefulWidget {
  const Selectpostition({super.key});

  @override
  _SelectpostitionState createState() => _SelectpostitionState();
}

class _SelectpostitionState extends State<Selectpostition> {
  GoogleMapController? mapController;
  LatLng _selectedPosition = const LatLng(13.736717, 100.523186);
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _placeSuggestions = [];
  final String _sessionToken = Uuid().v4();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best));

    setState(() {
      _selectedPosition = LatLng(position.latitude, position.longitude);
    });

    mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedPosition, 15));
    _getAddressFromLatLng(_selectedPosition);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
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
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    String apiKey = "YOUR_GOOGLE_MAPS_API_KEY";
    String requestUrl =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&sessiontoken=$_sessionToken&components=country:th";

    final response = await http.get(Uri.parse(requestUrl));

    if (response.statusCode == 200) {
      setState(() {
        _placeSuggestions = json.decode(response.body)['predictions'];
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    String apiKey = "YOUR_GOOGLE_MAPS_API_KEY";
    String requestUrl =
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey";

    final response = await http.get(Uri.parse(requestUrl));

    if (response.statusCode == 200) {
      var result = json.decode(response.body)['result'];
      double lat = result['geometry']['location']['lat'];
      double lng = result['geometry']['location']['lng'];

      setState(() {
        _selectedPosition = LatLng(lat, lng);
        _placeSuggestions = [];
        _isSearching = false;
      });

      mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedPosition, 15));
      _getAddressFromLatLng(_selectedPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedPosition, 15));
            },
            initialCameraPosition: CameraPosition(target: _selectedPosition, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onCameraMove: (position) {
              setState(() {
                _selectedPosition = position.target;
              });
            },
            onCameraIdle: () {
              _getAddressFromLatLng(_selectedPosition);
            },
          ),

          Center(
            child: Icon(Icons.location_pin, color: Colors.red, size: 50),
          ),

          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 2)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "ค้นหาสถานที่",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      suffixIcon: const Icon(Icons.search, color: Colors.grey),
                    ),
                    onChanged: (query) => _fetchPlaceSuggestions(query),
                  ),
                ),

                if (_isSearching && _placeSuggestions.isNotEmpty)
                  Container(
                    height: 200,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.builder(
                      itemCount: _placeSuggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_placeSuggestions[index]['description']),
                          onTap: () {
                            _getPlaceDetails(_placeSuggestions[index]['place_id']);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 2)],
              ),
              child: Column(
                children: [
                  Text(
                    _searchController.text.isNotEmpty ? _searchController.text : "กำลังโหลดที่อยู่...",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, _selectedPosition);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("เลือกที่นี่", style: TextStyle(fontSize: 18, color: Colors.white)),
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