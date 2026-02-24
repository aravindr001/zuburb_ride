import 'package:google_maps_flutter/google_maps_flutter.dart';

class RiderPreview {
  final String riderId;
  final String name;
  final double rating;
  final double distanceKm;
  final LatLng location;

  const RiderPreview({
    required this.riderId,
    required this.name,
    required this.rating,
    required this.distanceKm,
    required this.location,
  });
}

sealed class SchedulePickupState {
  final bool isScheduled;
  final DateTime? scheduledAt;
  final List<RiderPreview> riders;
  final String? selectedRiderId;
  final bool isLoadingRiders;
  final bool isSubmitting;
  final String? errorMessage;

  const SchedulePickupState({
    required this.isScheduled,
    required this.scheduledAt,
    required this.riders,
    required this.selectedRiderId,
    required this.isLoadingRiders,
    required this.isSubmitting,
    required this.errorMessage,
  });
}

final class SchedulePickupReady extends SchedulePickupState {
  const SchedulePickupReady({
    required super.isScheduled,
    required super.scheduledAt,
    required super.riders,
    required super.selectedRiderId,
    required super.isLoadingRiders,
    required super.isSubmitting,
    required super.errorMessage,
  });

  factory SchedulePickupReady.initial() => const SchedulePickupReady(
        isScheduled: false,
        scheduledAt: null,
        riders: [],
        selectedRiderId: null,
        isLoadingRiders: true,
        isSubmitting: false,
        errorMessage: null,
      );

  SchedulePickupReady copyWith({
    bool? isScheduled,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    List<RiderPreview>? riders,
    String? selectedRiderId,
    bool clearSelectedRider = false,
    bool? isLoadingRiders,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SchedulePickupReady(
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
      riders: riders ?? this.riders,
      selectedRiderId: clearSelectedRider ? null : (selectedRiderId ?? this.selectedRiderId),
      isLoadingRiders: isLoadingRiders ?? this.isLoadingRiders,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final class SchedulePickupBooked extends SchedulePickupState {
  final String rideId;
  final bool bookedForNow;

  const SchedulePickupBooked({
    required this.rideId,
    required this.bookedForNow,
    required super.isScheduled,
    required super.scheduledAt,
    required super.riders,
    required super.selectedRiderId,
    required super.isLoadingRiders,
    required super.isSubmitting,
    required super.errorMessage,
  });
}
