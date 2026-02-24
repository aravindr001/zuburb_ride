import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zuburb_ride/utils/geohash_utils.dart';
import 'package:zuburb_ride/utils/location_utils.dart';

import 'schedule_pickup_state.dart';

class SchedulePickupCubit extends Cubit<SchedulePickupState> {
  final LatLng pickup;
  final LatLng drop;
  final double distanceKm;

  bool _loadingInProgress = false;

  SchedulePickupCubit({
    required this.pickup,
    required this.drop,
    required this.distanceKm,
  }) : super(SchedulePickupReady.initial());

  Future<void> init() async {
    await loadRiders();
  }

  void selectRider(String riderId) {
    final current = _ready;
    emit(current.copyWith(selectedRiderId: riderId, clearError: true));
  }

  Future<void> setNow() async {
    final current = _ready;
    emit(
      current.copyWith(
        isScheduled: false,
        clearScheduledAt: true,
        clearError: true,
      ),
    );
    await loadRiders();
  }

  Future<void> setScheduled(DateTime at) async {
    final current = _ready;
    emit(
      current.copyWith(
        isScheduled: true,
        scheduledAt: at,
        clearError: true,
      ),
    );
    await loadRiders();
  }

  Future<void> loadRiders() async {
    if (_loadingInProgress) return;
    _loadingInProgress = true;

    final current = _ready;
    emit(current.copyWith(isLoadingRiders: true, clearError: true));

    try {
      const radiusKm = 10.0;
      final firestore = FirebaseFirestore.instance;
      final locationsRef = firestore.collection('rider_locations');

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
        docs = results.expand((items) => items).toList(growable: false);
      } catch (e) {
        debugPrint('Geohash rider-list query failed, fallback scan: $e');
        docs = const [];
      }

      if (docs.isEmpty) {
        final snapshot = await locationsRef.limit(500).get();
        docs = snapshot.docs;
      }

      final candidates = <({String riderId, LatLng location, double distanceKm})>[];
      final seen = <String>{};

      for (final doc in docs) {
        if (!seen.add(doc.id)) continue;

        final data = doc.data();
        final location = _readLocation(data);
        if (location == null) continue;

        final dKm = calculateDistance(
          pickup.latitude,
          pickup.longitude,
          location.latitude,
          location.longitude,
        );

        if (dKm > radiusKm) continue;

        candidates.add((riderId: doc.id, location: location, distanceKm: dKm));
      }

      if (candidates.isEmpty) {
        emit(
          _ready.copyWith(
            riders: const [],
            clearSelectedRider: true,
            isLoadingRiders: false,
          ),
        );
        return;
      }

      final riderDocs = await Future.wait(
        candidates.map(
          (candidate) => firestore.collection('riders').doc(candidate.riderId).get(),
        ),
      );

      final isScheduled = _ready.isScheduled;
      final scheduledAt = _ready.scheduledAt;
      if (isScheduled && scheduledAt == null) {
        emit(
          _ready.copyWith(
            riders: const [],
            clearSelectedRider: true,
            isLoadingRiders: false,
          ),
        );
        return;
      }

      final previews = <RiderPreview>[];

      for (var index = 0; index < candidates.length; index++) {
        final candidate = candidates[index];
        final riderDoc = riderDocs[index];
        final riderData = riderDoc.data();
        if (riderData == null) continue;

        final isOnline = riderData['isOnline'] == true;
        final isAvailable = riderData['isAvailable'] == true;
        final hasCurrentRide = riderData['currentRideId'] is String &&
            (riderData['currentRideId'] as String).trim().isNotEmpty;

        if (!isScheduled) {
          if (!isOnline || !isAvailable || hasCurrentRide) continue;
        } else {
          final acceptsScheduled = riderData['acceptsScheduledRides'] == true;
          if (!isOnline || !acceptsScheduled) continue;

          final matchesSchedule = _matchesScheduledAvailability(
            riderData: riderData,
            scheduledAt: scheduledAt!,
          );
          if (!matchesSchedule) continue;
        }

        final ratingRaw = riderData['rating'];
        final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;

        final nameRaw = riderData['name'];
        final name = (nameRaw is String && nameRaw.trim().isNotEmpty)
            ? nameRaw.trim()
            : 'Rider ${candidate.riderId.substring(0, 6)}';

        previews.add(
          RiderPreview(
            riderId: candidate.riderId,
            name: name,
            rating: rating,
            distanceKm: candidate.distanceKm,
            location: candidate.location,
          ),
        );
      }

      previews.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      String? selectedRiderId = _ready.selectedRiderId;
      final selectedStillExists =
          selectedRiderId != null && previews.any((rider) => rider.riderId == selectedRiderId);
      if (!selectedStillExists) {
        selectedRiderId = previews.isNotEmpty ? previews.first.riderId : null;
      }

      emit(
        _ready.copyWith(
          riders: previews,
          selectedRiderId: selectedRiderId,
          isLoadingRiders: false,
        ),
      );
    } catch (e) {
      emit(
        _ready.copyWith(
          isLoadingRiders: false,
          errorMessage: e.toString(),
        ),
      );
    } finally {
      _loadingInProgress = false;
    }
  }

  Future<void> confirmBooking() async {
    final current = _ready;
    emit(current.copyWith(isSubmitting: true, clearError: true));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      if (current.riders.isEmpty) {
        throw Exception('No riders available');
      }

      final selectedRiderId = current.selectedRiderId;
      if (selectedRiderId == null || selectedRiderId.trim().isEmpty) {
        throw Exception('Please select a rider');
      }

      RiderPreview? selectedRider;
      for (final rider in current.riders) {
        if (rider.riderId == selectedRiderId) {
          selectedRider = rider;
          break;
        }
      }

      if (selectedRider == null) {
        throw Exception('Selected rider is no longer available');
      }

      if (current.isScheduled) {
        final scheduledAt = current.scheduledAt;
        if (scheduledAt == null) {
          throw Exception('Please select scheduled date and time');
        }

        final firestore = FirebaseFirestore.instance;
        final rideRef = firestore.collection('rides').doc();
        final customerRef = firestore.collection('customers').doc(user.uid);
        final riderRef = firestore.collection('riders').doc(selectedRider.riderId);

        final batch = firestore.batch();

        batch.set(rideRef, {
          'customerId': user.uid,
          'riderId': selectedRider.riderId,
          'pickup': GeoPoint(pickup.latitude, pickup.longitude),
          'drop': GeoPoint(drop.latitude, drop.longitude),
          'distanceKm': distanceKm,
          'status': 'scheduled',
          'isScheduled': true,
          'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        batch.set(
          customerRef,
          {
            'scheduledRideIds': FieldValue.arrayUnion([rideRef.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        batch.set(
          riderRef,
          {
            'scheduledRideIds': FieldValue.arrayUnion([rideRef.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        await batch.commit();

        emit(
          SchedulePickupBooked(
            rideId: rideRef.id,
            bookedForNow: false,
            isScheduled: current.isScheduled,
            scheduledAt: current.scheduledAt,
            riders: current.riders,
            selectedRiderId: current.selectedRiderId,
            isLoadingRiders: false,
            isSubmitting: false,
            errorMessage: null,
          ),
        );
        return;
      }

      String? createdRideId;
      final firestore = FirebaseFirestore.instance;

      await firestore.runTransaction((tx) async {
        final riderRef = firestore.collection('riders').doc(selectedRider!.riderId);
        final customerRef = firestore.collection('customers').doc(user.uid);
        final riderSnap = await tx.get(riderRef);
        final riderData = riderSnap.data();
        if (riderData == null) throw Exception('Rider missing');

        final isOnline = riderData['isOnline'] == true;
        final isAvailable = riderData['isAvailable'] == true;
        final currentRideId = riderData['currentRideId'];
        final hasCurrentRide = currentRideId is String && currentRideId.trim().isNotEmpty;

        if (!isOnline || !isAvailable || hasCurrentRide) {
          throw Exception('Selected rider is not available now');
        }

        final rideRef = firestore.collection('rides').doc();
        createdRideId = rideRef.id;

        tx.set(rideRef, {
          'customerId': user.uid,
          'riderId': selectedRider.riderId,
          'pickup': GeoPoint(pickup.latitude, pickup.longitude),
          'drop': GeoPoint(drop.latitude, drop.longitude),
          'distanceKm': distanceKm,
          'status': 'requested',
          'isScheduled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(riderRef, {
          'isAvailable': false,
          'currentRideId': rideRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(
          customerRef,
          {
            'currentRideId': rideRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (createdRideId == null) {
        throw Exception('No riders available');
      }

      emit(
        SchedulePickupBooked(
          rideId: createdRideId!,
          bookedForNow: true,
          isScheduled: current.isScheduled,
          scheduledAt: current.scheduledAt,
          riders: current.riders,
          selectedRiderId: current.selectedRiderId,
          isLoadingRiders: false,
          isSubmitting: false,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(_ready.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }

  LatLng? _readLocation(Map<String, dynamic> data) {
    final locationRaw = data['location'];
    if (locationRaw is GeoPoint) {
      return LatLng(locationRaw.latitude, locationRaw.longitude);
    }

    if (locationRaw is Map) {
      final maybeGeo = locationRaw['geopoint'] ?? locationRaw['geoPoint'];
      if (maybeGeo is GeoPoint) {
        return LatLng(maybeGeo.latitude, maybeGeo.longitude);
      }
    }

    return null;
  }

  bool _matchesScheduledAvailability({
    required Map<String, dynamic> riderData,
    required DateTime scheduledAt,
  }) {
    final availabilityRaw = riderData['availabilitySchedule'];
    if (availabilityRaw is! Map) return false;

    final weekday = _weekdayKey(scheduledAt);
    final daySlotsRaw = availabilityRaw[weekday];
    if (daySlotsRaw is! List || daySlotsRaw.isEmpty) return false;

    final scheduledMinutes = scheduledAt.hour * 60 + scheduledAt.minute;

    for (final slotRaw in daySlotsRaw) {
      if (slotRaw is! Map) continue;

      final startRaw = slotRaw['start'];
      final endRaw = slotRaw['end'];
      if (startRaw is! String || endRaw is! String) continue;

      final startMinutes = _parseHmToMinutes(startRaw);
      final endMinutes = _parseHmToMinutes(endRaw);
      if (startMinutes == null || endMinutes == null) continue;
      if (endMinutes <= startMinutes) continue;

      if (scheduledMinutes >= startMinutes && scheduledMinutes < endMinutes) {
        return true;
      }
    }

    return false;
  }

  int? _parseHmToMinutes(String hm) {
    final parts = hm.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return hour * 60 + minute;
  }

  String _weekdayKey(DateTime dateTime) {
    switch (dateTime.weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  SchedulePickupReady get _ready {
    final current = state;
    if (current is SchedulePickupReady) return current;
    if (current is SchedulePickupBooked) {
      return SchedulePickupReady(
        isScheduled: current.isScheduled,
        scheduledAt: current.scheduledAt,
        riders: current.riders,
        selectedRiderId: current.selectedRiderId,
        isLoadingRiders: current.isLoadingRiders,
        isSubmitting: current.isSubmitting,
        errorMessage: current.errorMessage,
      );
    }
    return SchedulePickupReady.initial();
  }

}
