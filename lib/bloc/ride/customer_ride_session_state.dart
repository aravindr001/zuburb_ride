import 'package:google_maps_flutter/google_maps_flutter.dart';

sealed class CustomerRideSessionState {
  const CustomerRideSessionState();
}

final class CustomerRideSessionLoading extends CustomerRideSessionState {
  const CustomerRideSessionLoading();
}

final class CustomerRideSessionIdle extends CustomerRideSessionState {
  const CustomerRideSessionIdle();
}

final class CustomerRideSessionFindingDriver extends CustomerRideSessionState {
  final String rideId;

  const CustomerRideSessionFindingDriver({required this.rideId});
}

final class CustomerRideSessionTracking extends CustomerRideSessionState {
  final String rideId;
  final String riderId;
  final LatLng pickup;

  const CustomerRideSessionTracking({
    required this.rideId,
    required this.riderId,
    required this.pickup,
  });
}

final class CustomerRideSessionSafeHands extends CustomerRideSessionState {
  final String rideId;
  final String riderId;
  final LatLng pickup;

  const CustomerRideSessionSafeHands({
    required this.rideId,
    required this.riderId,
    required this.pickup,
  });
}

final class CustomerRideSessionRating extends CustomerRideSessionState {
  final String rideId;
  final String riderId;

  const CustomerRideSessionRating({
    required this.rideId,
    required this.riderId,
  });
}

final class CustomerRideSessionFailure extends CustomerRideSessionState {
  final String message;

  const CustomerRideSessionFailure(this.message);
}
