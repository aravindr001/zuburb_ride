import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:zuburb_ride/repository/routes_api_client.dart';
import 'package:zuburb_ride/utils/location_utils.dart';

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

      final bounds = getBounds(pickup.latitude, pickup.longitude, 10);

      final snapshot = await FirebaseFirestore.instance
          .collection('rider_locations')
          .where('lat', isGreaterThan: bounds['minLat'])
          .where('lat', isLessThan: bounds['maxLat'])
          .where('lng', isGreaterThan: bounds['minLng'])
          .where('lng', isLessThan: bounds['maxLng'])
          .get();

      for (final doc in snapshot.docs) {
        final riderId = doc.id;

        try {
          String? createdRideId;

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final riderRef =
                FirebaseFirestore.instance.collection('riders').doc(riderId);

            final riderSnapshot = await transaction.get(riderRef);

            if (!riderSnapshot.exists) {
              throw Exception('Rider missing');
            }

            if (riderSnapshot['isOnline'] != true) {
              throw Exception('Rider offline');
            }

            if (riderSnapshot['isAvailable'] != true) {
              throw Exception('Rider not available');
            }

            if (riderSnapshot['currentRideId'] != null) {
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
