import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:zuburb_ride/repository/routes_api_client.dart';

import 'driver_tracking_state.dart';

class DriverTrackingCubit extends Cubit<DriverTrackingState> {
  final String rideId;
  final String riderId;
  final LatLng pickup;
  final double nearPickupMeters;

  final RoutesApiClient _routesApi;

  String? _pickupOtp;
  bool _isPickupOtpVerified = false;
  bool _otpGenerationInProgress = false;

  DateTime? _lastRoutesRequestAt;
  LatLng? _lastRoutesOrigin;
  int? _routeDistanceMeters;
  int _routesRequestSeq = 0;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _riderLocationSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rideSub;

  DriverTrackingCubit({
    required this.rideId,
    required this.riderId,
    required this.pickup,
    this.nearPickupMeters = 100,
    RoutesApiClient? routesApi,
  })  : _routesApi = routesApi ?? RoutesApiClient(),
        super(const DriverTrackingLoading());

  void init() {
    _listenRide();
    _listenRiderLocation();
  }

  void _listenRide() {
    _rideSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen(
      (snapshot) {
        if (state is DriverTrackingCancelled || state is DriverTrackingRideCompleted) {
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final status = data['status'];
        if (status == 'completed' && state is! DriverTrackingRideCompleted) {
          _handleCompleted();
          return;
        }

        if (status == 'cancelled' && state is! DriverTrackingCancelled) {
          _handleCancelled('Ride cancelled by driver');
          return;
        }

        final pickupOtpRaw = data['pickupOtp'];
        final pickupOtp = switch (pickupOtpRaw) {
          String s => s,
          int i => i.toString(),
          _ => null,
        };

        final verifiedRaw = data['pickupOtpVerified'];
        final isVerified = (verifiedRaw == true) || (status == 'picked_up');

        final wasVerified = _isPickupOtpVerified;

        if (status == 'arrived_pickup') {
          _generatePickupOtpIfNeeded();
        }

        final otpChanged = pickupOtp != _pickupOtp;
        final verifiedChanged = isVerified != _isPickupOtpVerified;

        _pickupOtp = pickupOtp;
        _isPickupOtpVerified = isVerified;

        if (_isPickupOtpVerified && !wasVerified) {
          _handlePickupVerified();
          return;
        }

        if ((otpChanged || verifiedChanged) && state is DriverTrackingReady) {
          final current = state as DriverTrackingReady;
          emit(
            DriverTrackingReady(
              pickup: current.pickup,
              rider: current.rider,
              markers: current.markers,
              isNearPickup: current.isNearPickup,
              pickupOtp: _pickupOtp,
              isPickupOtpVerified: _isPickupOtpVerified,
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(DriverTrackingFailure(error.toString()));
      },
    );
  }

  Future<void> _generatePickupOtpIfNeeded() async {
    if (_otpGenerationInProgress) return;
    if (_pickupOtp != null && _pickupOtp!.trim().isNotEmpty) return;

    _otpGenerationInProgress = true;
    final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
    final otp = (1000 + Random.secure().nextInt(9000)).toString();

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(rideRef);
        final data = snap.data();
        if (data == null) return;

        final status = data['status'] as String?;
        if (status != 'arrived_pickup') return;

        final existingRaw = data['pickupOtp'];
        final existing = switch (existingRaw) {
          String s => s,
          int i => i.toString(),
          _ => '',
        };
        if (existing.trim().isNotEmpty) return;

        tx.update(rideRef, {
          'pickupOtp': otp,
          'pickupOtpCreatedAt': FieldValue.serverTimestamp(),
          'pickupOtpVerified': false,
        });
      });
    } finally {
      _otpGenerationInProgress = false;
    }
  }

  void _listenRiderLocation() {
    _riderLocationSub = FirebaseFirestore.instance
        .collection('rider_locations')
        .doc(riderId)
        .snapshots()
        .listen(
      (snapshot) {
        if (state is DriverTrackingCancelled || state is DriverTrackingRideCompleted || state is DriverTrackingPickupVerified || _isPickupOtpVerified) {
          return;
        }

        final data = snapshot.data();
        if (data == null) {
          emit(const DriverTrackingFailure('Rider location not found'));
          return;
        }

        final rider = _readRiderLatLng(data);
        if (rider == null) {
          emit(const DriverTrackingFailure('Rider location missing lat/lng'));
          return;
        }

        _maybeUpdateRouteDistance(origin: rider);

        final fallbackDistanceMeters = Geolocator.distanceBetween(
          pickup.latitude,
          pickup.longitude,
          rider.latitude,
          rider.longitude,
        );

        final distanceMeters = _routeDistanceMeters?.toDouble() ?? fallbackDistanceMeters;

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickup,
            infoWindow: const InfoWindow(title: 'Pickup'),
          ),
          Marker(
            markerId: const MarkerId('rider'),
            position: rider,
            infoWindow: const InfoWindow(title: 'Rider'),
          ),
        };

        emit(
          DriverTrackingReady(
            pickup: pickup,
            rider: rider,
            markers: markers,
            isNearPickup: distanceMeters <= nearPickupMeters,
            pickupOtp: _pickupOtp,
            isPickupOtpVerified: _isPickupOtpVerified,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(DriverTrackingFailure(error.toString()));
      },
    );
  }

  Future<void> _maybeUpdateRouteDistance({required LatLng origin}) async {
    if (_isPickupOtpVerified) return;
    if (state is DriverTrackingCancelled || state is DriverTrackingRideCompleted) return;

    final now = DateTime.now();
    final lastAt = _lastRoutesRequestAt;
    if (lastAt != null && now.difference(lastAt) < const Duration(seconds: 10)) {
      return;
    }

    final lastOrigin = _lastRoutesOrigin;
    if (lastOrigin != null) {
      final deltaMeters = Geolocator.distanceBetween(
        lastOrigin.latitude,
        lastOrigin.longitude,
        origin.latitude,
        origin.longitude,
      );
      if (deltaMeters < 30) {
        return;
      }
    }

    _lastRoutesRequestAt = now;
    _lastRoutesOrigin = origin;

    final requestSeq = ++_routesRequestSeq;
    final meters = await _routesApi.computeDrivingDistanceMeters(
      origin: origin,
      destination: pickup,
    );

    if (requestSeq != _routesRequestSeq) return;
    if (meters == null) return;

    _routeDistanceMeters = meters;

    final current = state;
    if (current is DriverTrackingReady) {
      emit(
        DriverTrackingReady(
          pickup: current.pickup,
          rider: current.rider,
          markers: current.markers,
          isNearPickup: meters <= nearPickupMeters,
          pickupOtp: current.pickupOtp,
          isPickupOtpVerified: current.isPickupOtpVerified,
        ),
      );
    }
  }

  void _handleCancelled(String message) {
    _riderLocationSub?.cancel();
    _rideSub?.cancel();
    emit(DriverTrackingCancelled(message));
  }

  void _handlePickupVerified() {
    _riderLocationSub?.cancel();
    emit(const DriverTrackingPickupVerified());
  }

  void _handleCompleted() {
    unawaited(_incrementCustomerTotalRidesIfNeeded());
    _riderLocationSub?.cancel();
    _rideSub?.cancel();
    emit(const DriverTrackingRideCompleted());
  }

  Future<void> _incrementCustomerTotalRidesIfNeeded() async {
    final firestore = FirebaseFirestore.instance;
    final rideRef = firestore.collection('rides').doc(rideId);

    await firestore.runTransaction((tx) async {
      final rideSnap = await tx.get(rideRef);
      final rideData = rideSnap.data();
      if (rideData == null) return;

      final statusRaw = rideData['status'];
      final status = statusRaw is String ? statusRaw.toLowerCase() : '';
      if (status != 'completed') return;

      if (rideData['customerTotalRidesIncrementedAt'] != null) return;

      final customerId = rideData['customerId'];
      if (customerId is! String || customerId.trim().isEmpty) return;

      final customerRef = firestore.collection('customers').doc(customerId);
      final customerSnap = await tx.get(customerRef);
      final customerData = customerSnap.data();
      if (customerData == null) return;

      final currentRaw = customerData['totalRides'];
      final current = (currentRaw is num) ? currentRaw.toInt() : 0;

      tx.update(customerRef, {
        'totalRides': current + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(rideRef, {
        'customerTotalRidesIncrementedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  LatLng? _readRiderLatLng(Map<String, dynamic> data) {
    final location = data['location'];
    if (location is GeoPoint) {
      return LatLng(location.latitude, location.longitude);
    }

    final lat = data['lat'];
    final lng = data['lng'];

    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }

    return null;
  }

  @override
  Future<void> close() async {
    await _riderLocationSub?.cancel();
    await _rideSub?.cancel();
    _routesApi.close();
    return super.close();
  }
}
