import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zuburb_ride/models/customer_profile_model.dart';
import 'package:zuburb_ride/models/ride_model.dart';

class RideRepository {
  final FirebaseFirestore _firestore;

  RideRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<CustomerProfileModel> watchCustomerProfile(String customerId) {
    return _firestore
        .collection('customers')
        .doc(customerId)
        .snapshots()
        .map(CustomerProfileModel.fromSnapshot);
  }

  Future<List<RideModel>> fetchRidesByIds(List<String> rideIds) async {
    final normalized = _normalizeIds(rideIds);
    if (normalized.isEmpty) return const <RideModel>[];

    final rides = <RideModel>[];
    for (final chunk in _chunk(normalized, 30)) {
      final snapshot = await _firestore
          .collection('rides')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        rides.add(RideModel.fromSnapshot(doc));
      }
    }

    rides.sort(_scheduledAscComparator);
    return rides;
  }

  Stream<List<RideModel>> watchScheduledRides(List<String> rideIds) {
    final normalized = _normalizeIds(rideIds);
    if (normalized.isEmpty) {
      return Stream<List<RideModel>>.value(const <RideModel>[]);
    }

    final controller = StreamController<List<RideModel>>();
    final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final ridesById = <String, RideModel>{};

    void emitMerged() {
      final merged = ridesById.values.toList(growable: false)..sort(_scheduledAscComparator);
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    for (final chunk in _chunk(normalized, 30)) {
      final sub = _firestore
          .collection('rides')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .listen(
        (snapshot) {
          for (final doc in snapshot.docs) {
            ridesById[doc.id] = RideModel.fromSnapshot(doc);
          }

          final currentIds = snapshot.docs.map((doc) => doc.id).toSet();
          for (final id in chunk) {
            if (!currentIds.contains(id)) {
              ridesById.remove(id);
            }
          }

          emitMerged();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );

      subscriptions.add(sub);
    }

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> cancelScheduledRide(String rideId, String customerId) async {
    final rideRef = _firestore.collection('rides').doc(rideId);
    final customerRef = _firestore.collection('customers').doc(customerId);

    await _firestore.runTransaction((tx) async {
      final rideSnap = await tx.get(rideRef);
      final rideData = rideSnap.data();
      if (rideData == null) {
        throw Exception('Ride not found');
      }

      final rideCustomerId = (rideData['customerId'] as String?)?.trim() ?? '';
      if (rideCustomerId != customerId) {
        throw Exception('Not allowed to cancel this ride');
      }

      final status = ((rideData['status'] as String?) ?? '').toLowerCase();
      if (status != 'scheduled') {
        throw Exception('Ride can no longer be cancelled');
      }

      final scheduledAtRaw = rideData['scheduledAt'];
      if (scheduledAtRaw is! Timestamp) {
        throw Exception('Ride schedule time missing');
      }

      final scheduledAtLocal = scheduledAtRaw.toDate().toLocal();
      final cutoff = scheduledAtLocal.subtract(const Duration(hours: 1));
      if (!DateTime.now().isBefore(cutoff)) {
        throw Exception('Cannot cancel within 1 hour of ride');
      }

      tx.set(
        rideRef,
        {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        customerRef,
        {
          'scheduledRideIds': FieldValue.arrayRemove([rideId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final riderId = (rideData['riderId'] as String?)?.trim() ?? '';
      if (riderId.isNotEmpty) {
        final riderRef = _firestore.collection('riders').doc(riderId);
        tx.set(
          riderRef,
          {
            'scheduledRideIds': FieldValue.arrayRemove([rideId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  List<String> _normalizeIds(List<String> ids) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (!seen.add(trimmed)) continue;
      normalized.add(trimmed);
    }

    return normalized;
  }

  List<List<String>> _chunk(List<String> ids, int size) {
    final chunks = <List<String>>[];
    for (var index = 0; index < ids.length; index += size) {
      final end = (index + size) > ids.length ? ids.length : index + size;
      chunks.add(ids.sublist(index, end));
    }
    return chunks;
  }

  int _scheduledAscComparator(RideModel a, RideModel b) {
    final aTime = a.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return aTime.compareTo(bTime);
  }
}
