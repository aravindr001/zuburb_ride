import 'package:zuburb_ride/models/ride_model.dart';

sealed class ScheduledRidesState {
  const ScheduledRidesState();
}

final class ScheduledRidesLoading extends ScheduledRidesState {
  const ScheduledRidesLoading();
}

final class ScheduledRidesLoaded extends ScheduledRidesState {
  final List<RideModel> rides;

  const ScheduledRidesLoaded(this.rides);

  int get count => rides.length;

  List<RideModel> get upcoming {
    return rides
        .where(
          (ride) => ride.status.toLowerCase() != 'cancelled' && ride.status.toLowerCase() != 'completed',
        )
        .toList(growable: false);
  }
}

final class ScheduledRideActivated extends ScheduledRidesLoaded {
  final RideModel activeRide;

  const ScheduledRideActivated({
    required List<RideModel> rides,
    required this.activeRide,
  }) : super(rides);
}

final class ScheduledRidesError extends ScheduledRidesState {
  final String message;

  const ScheduledRidesError(this.message);
}
