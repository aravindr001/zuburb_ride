import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:zuburb_ride/repository/routes_api_client.dart';
import 'package:zuburb_ride/utils/location_utils.dart';
import 'package:zuburb_ride/utils/geohash_utils.dart';

import 'ride_confirmation_state.dart';

class RideConfirmationCubit extends Cubit<RideConfirmationState> {
  final LatLng pickup;
  final LatLng drop;

  final RoutesApiClient _routesApi;

  RideConfirmationCubit({
    required this.pickup,
    required this.drop,
    RoutesApiClient? routesApi,
  })  : _routesApi = routesApi ?? RoutesApiClient(),
        super(const RideConfirmationInitial());

  void init() {
    final distanceMeters = Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      drop.latitude,
      drop.longitude,
    );

    emit(
      RideConfirmationReady(
        distanceKm: distanceMeters / 1000,
        isRouteDistance: false,
      ),
    );

    // Upgrade to road distance (Google Routes API) when available.
    unawaited(_updateDistanceUsingRoutesApi());
  }

  Future<void> _updateDistanceUsingRoutesApi() async {
    final meters = await _routesApi.computeDrivingDistanceMeters(
      origin: pickup,
      destination: drop,
    );
    if (meters == null) return;

    // Don't change the distance while the user is submitting.
    final current = state;
    if (current is! RideConfirmationReady) return;

    final km = meters / 1000.0;
    if ((km - current.distanceKm).abs() < 0.01) return;

    emit(RideConfirmationReady(distanceKm: km, isRouteDistance: true));
  }

  Future<void> confirmRide() async {
    final currentDistance = state.distanceKm;
    emit(
      RideConfirmationSubmitting(
        distanceKm: currentDistance,
        isRouteDistance: state.isRouteDistance,
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(
          RideConfirmationFailure(
            distanceKm: currentDistance,
            isRouteDistance: state.isRouteDistance,
            message: 'User not logged in',
          ),
        );
        return;
      }

      final customerId = user.uid;

        const radiusKm = 10.0;

      final locationsRef = FirebaseFirestore.instance.collection('rider_locations');

      // Preferred approach: query by geohash prefixes (fast), then verify exact
      // distance using the stored GeoPoint.
      final prefixes = geohashPrefixesForRadius(center: pickup, radiusKm: radiusKm);

      Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> queryByPrefix(String prefix) {
        return locationsRef
            .orderBy('geohash')
            .startAt([prefix])
            .endAt([geohashPrefixEnd(prefix)])
            .limit(200)
            .get()
            .then((snap) => snap.docs);
      }

      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      try {
        final results = await Future.wait(prefixes.map(queryByPrefix));
        docs = results.expand((e) => e).toList(growable: false);
      } catch (e) {
        debugPrint('Geohash query failed, falling back to scan: $e');
        docs = const [];
      }

      // Fallback: small-batch scan (works without geohash field).
      if (docs.isEmpty) {
        final snapshot = await locationsRef.limit(500).get();
        docs = snapshot.docs;
      }

      final candidates = <({String riderId, LatLng latLng, double distanceKm})>[];

      LatLng? readLatLng(Map<String, dynamic> data) {
        final location = data['location'];
        if (location is GeoPoint) {
          return LatLng(location.latitude, location.longitude);
        }

        // Common alternative shape: { location: { geopoint: GeoPoint, ... } }
        if (location is Map) {
          final maybeGeo = location['geopoint'] ?? location['geoPoint'];
          if (maybeGeo is GeoPoint) {
            return LatLng(maybeGeo.latitude, maybeGeo.longitude);
          }
        }
        return null;
      }

      for (final doc in docs) {
        final data = doc.data();
        final latLng = readLatLng(data);
        if (latLng == null) continue;

        final dKm = calculateDistance(
          pickup.latitude,
          pickup.longitude,
          latLng.latitude,
          latLng.longitude,
        );

        if (dKm > radiusKm) continue;

        candidates.add((riderId: doc.id, latLng: latLng, distanceKm: dKm));
      }

      candidates.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      for (final candidate in candidates) {
        final riderId = candidate.riderId;

        try {
          String? createdRideId;

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final riderRef =
                FirebaseFirestore.instance.collection('riders').doc(riderId);
            final customerRef =
                FirebaseFirestore.instance.collection('customers').doc(customerId);

            final riderSnapshot = await transaction.get(riderRef);

            if (!riderSnapshot.exists) {
              throw Exception('Rider missing');
            }

            final data = riderSnapshot.data();
            if (data == null) {
              throw Exception('Rider missing data');
            }

            // Be tolerant to missing fields to avoid skipping all candidates.
            // If the field is missing, we assume online/available.
            final isOnline = (data['isOnline'] is bool) ? (data['isOnline'] as bool) : true;
            final isAvailable =
                (data['isAvailable'] is bool) ? (data['isAvailable'] as bool) : true;
            final currentRideId = data['currentRideId'];

            if (!isOnline) {
              throw Exception('Rider offline');
            }

            if (!isAvailable) {
              throw Exception('Rider not available');
            }

            if (currentRideId is String && currentRideId.trim().isNotEmpty) {
              throw Exception('Rider already assigned');
            }

            final rideRef = FirebaseFirestore.instance.collection('rides').doc();
            createdRideId = rideRef.id;

            transaction.set(rideRef, {
              'customerId': customerId,
              'riderId': riderId,
              'pickup': GeoPoint(pickup.latitude, pickup.longitude),
              'drop': GeoPoint(drop.latitude, drop.longitude),
              'distanceKm': currentDistance,
              'status': 'requested',
              'createdAt': FieldValue.serverTimestamp(),
            });

            transaction.update(riderRef, {
              'isAvailable': false,
              'currentRideId': rideRef.id,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            transaction.set(
              customerRef,
              {
                'currentRideId': rideRef.id,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          });

          if (createdRideId != null) {
            emit(
              RideConfirmationBooked(
                distanceKm: currentDistance,
                isRouteDistance: state.isRouteDistance,
                rideId: createdRideId!,
              ),
            );
            return;
          }
        } catch (err) {
          debugPrint('Failed booking with rider $riderId: $err');
          continue;
        }
      }

      emit(
        RideConfirmationNoRiders(
          distanceKm: currentDistance,
          isRouteDistance: state.isRouteDistance,
        ),
      );
    } catch (e) {
      emit(
        RideConfirmationFailure(
          distanceKm: currentDistance,
          isRouteDistance: state.isRouteDistance,
          message: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _routesApi.close();
    return super.close();
  }
}
