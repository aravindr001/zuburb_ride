sealed class RideConfirmationState {
  final double distanceKm;
  const RideConfirmationState({required this.distanceKm});
}

final class RideConfirmationInitial extends RideConfirmationState {
  const RideConfirmationInitial() : super(distanceKm: 0);
}

final class RideConfirmationReady extends RideConfirmationState {
  const RideConfirmationReady({required super.distanceKm});
}

final class RideConfirmationSubmitting extends RideConfirmationState {
  const RideConfirmationSubmitting({required super.distanceKm});
}

final class RideConfirmationBooked extends RideConfirmationState {
  final String rideId;
  const RideConfirmationBooked({required super.distanceKm, required this.rideId});
}

final class RideConfirmationNoRiders extends RideConfirmationState {
  const RideConfirmationNoRiders({required super.distanceKm});
}

final class RideConfirmationFailure extends RideConfirmationState {
  final String message;
  const RideConfirmationFailure({required super.distanceKm, required this.message});
}
