import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../utils/location_utils.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // =============================
  // GET USER LOCATION
  // =============================
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);

      _markers.add(
        Marker(
          markerId: const MarkerId("me"),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: "You"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });

    await _fetchNearbyRiders(position.latitude, position.longitude);
  }

  // =============================
  // FETCH RIDERS + ADD MARKERS
  // =============================
  Future<void> _fetchNearbyRiders(double userLat, double userLng) async {
    final bounds = getBounds(userLat, userLng, 10);

    final snapshot = await FirebaseFirestore.instance
        .collection('rider_locations')
        .where('lat', isGreaterThan: bounds['minLat'])
        .where('lat', isLessThan: bounds['maxLat'])
        .where('lng', isGreaterThan: bounds['minLng'])
        .where('lng', isLessThan: bounds['maxLng'])
        .get();

    Set<Marker> newMarkers = {};

    for (var doc in snapshot.docs) {
      final riderId = doc.id;
      final lat = doc['lat'];
      final lng = doc['lng'];

      final riderDoc = await FirebaseFirestore.instance
          .collection('riders')
          .doc(riderId)
          .get();

      if (!riderDoc.exists) continue;

      if (riderDoc['isOnline'] == true && riderDoc['isAvailable'] == true) {
        final distance = calculateDistance(userLat, userLng, lat, lng);

        if (distance <= 10) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(riderId),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: riderDoc['phone'] ?? "Rider",
                snippet: "${distance.toStringAsFixed(2)} km away",
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );
        }
      }
    }

    setState(() {
      _markers = {
        _markers.firstWhere((m) => m.markerId.value == "me"),
        ...newMarkers,
      };
    });
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
       body: _currentPosition == null
          ? const Center(
              child:
                  CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 18,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.all(
                          16),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            ElevatedButton(
                          onPressed: () {
                            // TODO: Ride Now
                          },
                          child:
                              const Text(
                                  "Ride Now"),
                        ),
                      ),
                      const SizedBox(
                          width: 12),
                      Expanded(
                        child:
                            OutlinedButton(
                          onPressed: () {
                            // TODO: Schedule
                          },
                          child:
                              const Text(
                                  "Schedule"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}



