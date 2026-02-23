import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ride_rating_state.dart';

class RideRatingCubit extends Cubit<RideRatingState> {
  final String rideId;
  final String riderId;

  RideRatingCubit({required this.rideId, required this.riderId})
      : super(const RideRatingEditing(rating: 0));

  void setRating(int rating) {
    final clamped = rating.clamp(0, 5);
    emit(RideRatingEditing(rating: clamped));
  }

  Future<void> submit() async {
    final rating = state.rating;
    if (rating <= 0) {
      emit(const RideRatingFailure(rating: 0, message: 'Please select a rating'));
      emit(const RideRatingEditing(rating: 0));
      return;
    }

    emit(RideRatingSubmitting(rating: rating));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;
      final rideRef = firestore.collection('rides').doc(rideId);
      final riderRef = firestore.collection('riders').doc(riderId);
      final customerRef = firestore.collection('customers').doc(uid);

      await firestore.runTransaction((tx) async {
        final rideSnap = await tx.get(rideRef);
        final rideData = rideSnap.data();
        if (rideData == null) {
          throw Exception('Ride not found');
        }

        final customerId = rideData['customerId'];
        if (customerId is! String || customerId != uid) {
          throw Exception('Not allowed to rate this ride');
        }

        final statusRaw = rideData['status'];
        final status = statusRaw is String ? statusRaw.toLowerCase() : '';
        if (status != 'completed') {
          throw Exception('Ride is not completed yet');
        }

        if (rideData['riderRating'] != null || rideData['riderRatedAt'] != null) {
          final ratedBy = rideData['riderRatedBy'];
          if (ratedBy == uid) {
            return;
          }
          throw Exception('Ride already rated');
        }

        final riderSnap = await tx.get(riderRef);
        final riderData = riderSnap.data();
        if (riderData == null) {
          throw Exception('Rider not found');
        }

        final currentAvgRaw = riderData['rating'];
        final currentAvg = (currentAvgRaw is num) ? currentAvgRaw.toDouble() : 0.0;

        final countRaw = riderData['ratingCount'];
        final count = (countRaw is num) ? countRaw.toInt() : 0;

        final newCount = count + 1;
        final newAvg = ((currentAvg * count) + rating) / newCount;

        tx.update(riderRef, {
          'rating': newAvg,
          'ratingCount': newCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(rideRef, {
          'riderRating': rating,
          'riderRatedAt': FieldValue.serverTimestamp(),
          'riderRatedBy': uid,
        });

        tx.set(
          customerRef,
          {
            'currentRideId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      emit(RideRatingSubmitted(rating: rating));
    } catch (e) {
      emit(RideRatingFailure(rating: rating, message: e.toString()));
      emit(RideRatingEditing(rating: rating));
    }
  }
}
