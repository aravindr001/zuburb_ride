import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideModel {
  final String id;
  final bool isScheduled;
  final DateTime? scheduledAt;
  final String status;
  final String customerId;
  final String riderId;
  final String pickupAddress;
  final String dropAddress;
  final LatLng? pickup;
  final LatLng? drop;
  final double? distanceKm;

  const RideModel({
    required this.id,
    required this.isScheduled,
    required this.scheduledAt,
    required this.status,
    required this.customerId,
    required this.riderId,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickup,
    required this.drop,
    required this.distanceKm,
  });

  factory RideModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};

    final pickupGeo = data['pickup'];
    final dropGeo = data['drop'];
    final scheduledAtRaw = data['scheduledAt'];

    return RideModel(
      id: snapshot.id,
      isScheduled: data['isScheduled'] == true,
      scheduledAt: scheduledAtRaw is Timestamp ? scheduledAtRaw.toDate() : null,
      status: (data['status'] as String?)?.trim() ?? 'unknown',
      customerId: (data['customerId'] as String?)?.trim() ?? '',
      riderId: (data['riderId'] as String?)?.trim() ?? '',
      pickupAddress: (data['pickupAddress'] as String?)?.trim() ?? 'Pickup location',
      dropAddress: (data['dropAddress'] as String?)?.trim() ?? 'Drop location',
      pickup: pickupGeo is GeoPoint ? LatLng(pickupGeo.latitude, pickupGeo.longitude) : null,
      drop: dropGeo is GeoPoint ? LatLng(dropGeo.latitude, dropGeo.longitude) : null,
      distanceKm: (data['distanceKm'] is num) ? (data['distanceKm'] as num).toDouble() : null,
    );
  }
}
