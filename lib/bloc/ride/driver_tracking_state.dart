import 'package:google_maps_flutter/google_maps_flutter.dart';

sealed class DriverTrackingState {
  const DriverTrackingState();
}

final class DriverTrackingLoading extends DriverTrackingState {
  const DriverTrackingLoading();
}

final class DriverTrackingReady extends DriverTrackingState {
  final LatLng pickup;
  final LatLng rider;
  final Set<Marker> markers;
  final bool isNearPickup;
  final String? pickupOtp;
  final bool isPickupOtpVerified;

  const DriverTrackingReady({
    required this.pickup,
    required this.rider,
    required this.markers,
    required this.isNearPickup,
    required this.pickupOtp,
    required this.isPickupOtpVerified,
  });
}

final class DriverTrackingPickupVerified extends DriverTrackingState {
  const DriverTrackingPickupVerified();
}

final class DriverTrackingRideCompleted extends DriverTrackingState {
  const DriverTrackingRideCompleted();
}

final class DriverTrackingCancelled extends DriverTrackingState {
  final String message;
  const DriverTrackingCancelled(this.message);
}

final class DriverTrackingFailure extends DriverTrackingState {
  final String message;
  const DriverTrackingFailure(this.message);
}
