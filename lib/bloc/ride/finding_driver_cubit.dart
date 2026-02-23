import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'finding_driver_state.dart';

class FindingDriverCubit extends Cubit<FindingDriverState> {
  final String rideId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  FindingDriverCubit({required this.rideId})
      : super(const FindingDriverLoading());

  void init() {
    emit(const FindingDriverSearching());

    _subscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) {
          emit(const FindingDriverNotFound());
          return;
        }

        final status = data['status'];
        if (status == 'accepted') {
          if (state is FindingDriverAccepted) return;

          final riderId = data['riderId'];
          final pickup = data['pickup'];

          if (riderId is! String) {
            emit(const FindingDriverFailure('Ride accepted but riderId missing'));
            return;
          }

          if (pickup is! GeoPoint) {
            emit(const FindingDriverFailure('Ride accepted but pickup missing'));
            return;
          }

          emit(
            FindingDriverAccepted(
              riderId: riderId,
              pickupLat: pickup.latitude,
              pickupLng: pickup.longitude,
            ),
          );
        } else if (status == 'cancelled') {
          emit(const FindingDriverCancelled());
        } else {
          emit(const FindingDriverSearching());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(FindingDriverFailure(error.toString()));
      },
    );
  }

  Future<void> cancelRide() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        emit(const FindingDriverFailure('User not logged in'));
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final rideRef = firestore.collection('rides').doc(rideId);
      final customerRef = firestore.collection('customers').doc(uid);

      await firestore.runTransaction((tx) async {
        final rideSnap = await tx.get(rideRef);
        final rideData = rideSnap.data();
        if (rideData == null) {
          throw Exception('Ride not found');
        }

        tx.update(rideRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        final riderId = rideData['riderId'];
        if (riderId is String && riderId.trim().isNotEmpty) {
          final riderRef = firestore.collection('riders').doc(riderId);
          tx.set(
            riderRef,
            {
              'isAvailable': true,
              'currentRideId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        tx.set(
          customerRef,
          {
            'currentRideId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      emit(FindingDriverFailure(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
