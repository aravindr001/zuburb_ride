import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zuburb_ride/presentation/screens/finding_driver_screen.dart';

class RideConfirmationScreen extends StatefulWidget {
  final LatLng pickup;
  final LatLng drop;

  const RideConfirmationScreen({
    super.key,
    required this.pickup,
    required this.drop,
  });

  @override
  State<RideConfirmationScreen> createState() => _RideConfirmationScreenState();
}

class _RideConfirmationScreenState extends State<RideConfirmationScreen> {
  double _distanceKm = 0;

  @override
  void initState() {
    super.initState();
    _calculateDistance();
  }

  void _calculateDistance() {
    final distanceMeters = Geolocator.distanceBetween(
      widget.pickup.latitude,
      widget.pickup.longitude,
      widget.drop.latitude,
      widget.drop.longitude,
    );

    setState(() {
      _distanceKm = distanceMeters / 1000;
    });
  }

  Future<void> _confirmRide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final customerId = user.uid;

    final bounds = _getBounds(
      widget.pickup.latitude,
      widget.pickup.longitude,
      10,
    );

    final snapshot = await FirebaseFirestore.instance
        .collection('rider_locations')
        .where('lat', isGreaterThan: bounds['minLat'])
        .where('lat', isLessThan: bounds['maxLat'])
        .where('lng', isGreaterThan: bounds['minLng'])
        .where('lng', isLessThan: bounds['maxLng'])
        .get();

    for (var doc in snapshot.docs) {
      final riderId = doc.id;

      try {
        String? createdRideId;

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final riderRef = FirebaseFirestore.instance
              .collection('riders')
              .doc(riderId);

          final riderSnapshot = await transaction.get(riderRef);

          if (!riderSnapshot.exists ||
              riderSnapshot['isOnline'] != true ||
              riderSnapshot['isAvailable'] != true) {
            throw Exception();
          }

          final rideRef = FirebaseFirestore.instance.collection('rides').doc();

          createdRideId = rideRef.id;

          transaction.set(rideRef, {
            "customerId": customerId,
            "riderId": riderId,
            "pickup": GeoPoint(widget.pickup.latitude, widget.pickup.longitude),
            "drop": GeoPoint(widget.drop.latitude, widget.drop.longitude),
            "distanceKm": _distanceKm,
            "status": "requested",
            "createdAt": FieldValue.serverTimestamp(),
          });

          transaction.update(riderRef, {
            "isAvailable": false,
            "currentRideId": rideRef.id,
            "updatedAt": FieldValue.serverTimestamp(),
          });
        });

        if (!mounted || createdRideId == null) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Ride booked")));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FindingDriverScreen(rideId: createdRideId!),
          ),
        );

        return;
      } catch (_) {
        continue;
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("No riders available")));
  }

  Map<String, double> _getBounds(double lat, double lng, double radiusKm) {
    const earthRadius = 6371;

    final latDelta = (radiusKm / earthRadius) * (180 / 3.141592653589793);

    final lngDelta = latDelta / (cos(lat * 3.141592653589793 / 180));

    return {
      "minLat": lat - latDelta,
      "maxLat": lat + latDelta,
      "minLng": lng - lngDelta,
      "maxLng": lng + lngDelta,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Ride")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pickup", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("${widget.pickup.latitude}, ${widget.pickup.longitude}"),

            const SizedBox(height: 20),

            const Text("Drop", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("${widget.drop.latitude}, ${widget.drop.longitude}"),

            const SizedBox(height: 20),

            Text(
              "Distance: ${_distanceKm.toStringAsFixed(2)} km",
              style: const TextStyle(fontSize: 18),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmRide,
                child: const Text("Confirm Ride"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
