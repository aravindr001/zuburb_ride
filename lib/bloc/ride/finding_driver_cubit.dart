import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
      await FirebaseFirestore.instance.collection('rides').doc(rideId).update({
        'status': 'cancelled',
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
