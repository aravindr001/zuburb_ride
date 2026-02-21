import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() =>
      _SelectLocationScreenState();
}

class _SelectLocationScreenState
    extends State<SelectLocationScreen> {

  GoogleMapController? _mapController;
  LatLng? _pickupLocation;
  LatLng? _dropLocation;

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    LocationPermission permission;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    final pickup = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _pickupLocation = pickup;
      _markers.add(
        Marker(
          markerId: const MarkerId("pickup"),
          position: pickup,
          infoWindow: const InfoWindow(title: "Pickup"),
        ),
      );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(pickup, 15),
    );
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _dropLocation = position;

      _markers.removeWhere(
        (marker) => marker.markerId.value == "drop",
      );

      _markers.add(
        Marker(
          markerId: const MarkerId("drop"),
          position: position,
          infoWindow: const InfoWindow(title: "Drop"),
        ),
      );
    });
  }

  void _confirmSelection() {
    if (_pickupLocation == null || _dropLocation == null) return;

    Navigator.pop(context, {
      "pickup": _pickupLocation,
      "drop": _dropLocation,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Destination"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629),
              zoom: 5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: _onMapTap,
            markers: _markers,
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed:
                  _dropLocation == null ? null : _confirmSelection,
              child: const Text("Confirm Location"),
            ),
          ),
        ],
      ),
    );
  }
}