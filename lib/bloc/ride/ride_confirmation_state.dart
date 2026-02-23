sealed class RideConfirmationState {
  final double distanceKm;
  final bool isRouteDistance;
  const RideConfirmationState({
    required this.distanceKm,
    required this.isRouteDistance,
  });
}

final class RideConfirmationInitial extends RideConfirmationState {
  const RideConfirmationInitial() : super(distanceKm: 0, isRouteDistance: false);
}

final class RideConfirmationReady extends RideConfirmationState {
  const RideConfirmationReady({required super.distanceKm, required super.isRouteDistance});
}

final class RideConfirmationSubmitting extends RideConfirmationState {
  const RideConfirmationSubmitting({required super.distanceKm, required super.isRouteDistance});
}

final class RideConfirmationBooked extends RideConfirmationState {
  final String rideId;
  const RideConfirmationBooked({
    required super.distanceKm,
    required super.isRouteDistance,
    required this.rideId,
  });
}

final class RideConfirmationNoRiders extends RideConfirmationState {
  const RideConfirmationNoRiders({required super.distanceKm, required super.isRouteDistance});
}

final class RideConfirmationFailure extends RideConfirmationState {
  final String message;
  const RideConfirmationFailure({
    required super.distanceKm,
    required super.isRouteDistance,
    required this.message,
  });
}
