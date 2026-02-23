import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'customer_ride_session_state.dart';

class CustomerRideSessionCubit extends Cubit<CustomerRideSessionState> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _customerSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rideSub;

  String? _activeRideId;

  CustomerRideSessionCubit() : super(const CustomerRideSessionLoading());

  void init() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      emit(const CustomerRideSessionIdle());
      return;
    }

    _customerSub = FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        final data = snapshot.data();
        final currentRideIdRaw = data?['currentRideId'];
        final currentRideId =
            (currentRideIdRaw is String && currentRideIdRaw.trim().isNotEmpty)
                ? currentRideIdRaw
                : null;

        if (currentRideId == null) {
          _activeRideId = null;
          _rideSub?.cancel();
          _rideSub = null;
          emit(const CustomerRideSessionIdle());
          return;
        }

        if (_activeRideId == currentRideId && _rideSub != null) {
          return;
        }

        _listenRide(currentRideId);
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(CustomerRideSessionFailure(error.toString()));
      },
    );
  }

  void _listenRide(String rideId) {
    _activeRideId = rideId;
    _rideSub?.cancel();

    _rideSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) {
          unawaited(_clearCurrentRideIdIfMatches(rideId));
          emit(const CustomerRideSessionIdle());
          return;
        }

        final statusRaw = data['status'];
        final status = statusRaw is String ? statusRaw.toLowerCase() : '';

        final riderIdRaw = data['riderId'];
        final riderId =
            (riderIdRaw is String && riderIdRaw.trim().isNotEmpty) ? riderIdRaw : null;

        final pickup = _readPickup(data);

        if (status == 'requested') {
          emit(CustomerRideSessionFindingDriver(rideId: rideId));
          return;
        }

        if (status == 'accepted' || status == 'arrived_pickup') {
          if (riderId == null || pickup == null) {
            emit(CustomerRideSessionFindingDriver(rideId: rideId));
            return;
          }
          emit(
            CustomerRideSessionTracking(
              rideId: rideId,
              riderId: riderId,
              pickup: pickup,
            ),
          );
          return;
        }

        if (status == 'picked_up') {
          if (riderId == null || pickup == null) {
            emit(const CustomerRideSessionIdle());
            return;
          }
          emit(
            CustomerRideSessionSafeHands(
              rideId: rideId,
              riderId: riderId,
              pickup: pickup,
            ),
          );
          return;
        }

        if (status == 'completed') {
          final alreadyRated = data['riderRating'] != null || data['riderRatedAt'] != null;
          if (!alreadyRated && riderId != null) {
            emit(CustomerRideSessionRating(rideId: rideId, riderId: riderId));
          } else {
            emit(const CustomerRideSessionIdle());
          }
          unawaited(_clearCurrentRideIdIfMatches(rideId));
          return;
        }

        if (status == 'cancelled') {
          unawaited(_clearCurrentRideIdIfMatches(rideId));
          emit(const CustomerRideSessionIdle());
          return;
        }

        emit(CustomerRideSessionFindingDriver(rideId: rideId));
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(CustomerRideSessionFailure(error.toString()));
      },
    );
  }

  LatLng? _readPickup(Map<String, dynamic> data) {
    final pickup = data['pickup'];
    if (pickup is GeoPoint) {
      return LatLng(pickup.latitude, pickup.longitude);
    }
    return null;
  }

  Future<void> _clearCurrentRideIdIfMatches(String rideId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    final customerRef = firestore.collection('customers').doc(uid);

    await firestore.runTransaction((tx) async {
      final customerSnap = await tx.get(customerRef);
      final customerData = customerSnap.data();
      if (customerData == null) return;

      final currentRideId = customerData['currentRideId'];
      if (currentRideId is! String || currentRideId != rideId) return;

      tx.update(customerRef, {
        'currentRideId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> close() async {
    await _rideSub?.cancel();
    await _customerSub?.cancel();
    return super.close();
  }
}
