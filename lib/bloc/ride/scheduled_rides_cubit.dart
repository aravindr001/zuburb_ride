import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/models/ride_model.dart';
import 'package:zuburb_ride/repository/ride_repository.dart';
import 'package:zuburb_ride/services/local_notification_service.dart';

import 'scheduled_rides_state.dart';

class ScheduledRidesCubit extends Cubit<ScheduledRidesState> {
  final RideRepository _rideRepository;
  final String customerId;

  StreamSubscription<dynamic>? _customerSub;
  StreamSubscription<dynamic>? _ridesSub;
  List<String>? _currentIds;
  final Map<String, String> _lastStatusesByRideId = <String, String>{};
  String? _lastActivatedRideId;

  ScheduledRidesCubit({
    required RideRepository rideRepository,
    required this.customerId,
  })  : _rideRepository = rideRepository,
        super(const ScheduledRidesLoading());

  void init() {
    if (customerId.trim().isEmpty) {
      emit(const ScheduledRidesError('Customer not found'));
      return;
    }

    _customerSub?.cancel();
    _customerSub = _rideRepository.watchCustomerProfile(customerId).listen(
      (profile) {
        final ids = profile.scheduledRideIds;
        if (_currentIds != null && _sameIds(_currentIds!, ids)) return;

        _currentIds = ids;
        _ridesSub?.cancel();

        if (ids.isEmpty) {
          emit(const ScheduledRidesLoaded(<RideModel>[]));
          return;
        }

        _ridesSub = _rideRepository.watchScheduledRides(ids).listen(
          (rides) async {
            for (final ride in rides) {
              final previousStatus = _lastStatusesByRideId[ride.id]?.toLowerCase();
              final currentStatus = ride.status.toLowerCase();
              if (previousStatus == 'scheduled' && currentStatus == 'requested') {
                await LocalNotificationService.showScheduledRideStarting(ride);
              }
              _lastStatusesByRideId[ride.id] = ride.status;
            }

            final knownIds = rides.map((ride) => ride.id).toSet();
            _lastStatusesByRideId.removeWhere((id, _) => !knownIds.contains(id));

            final activeRide = _firstActiveRide(rides);
            if (activeRide != null) {
              if (_lastActivatedRideId != activeRide.id) {
                _lastActivatedRideId = activeRide.id;
                emit(ScheduledRideActivated(rides: rides, activeRide: activeRide));
                return;
              }
            } else {
              _lastActivatedRideId = null;
            }

            emit(ScheduledRidesLoaded(rides));
          },
          onError: (Object error, StackTrace stackTrace) {
            emit(ScheduledRidesError(error.toString()));
          },
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(ScheduledRidesError(error.toString()));
      },
    );
  }

  Future<void> cancelScheduledRide(String rideId) async {
    try {
      await _rideRepository.cancelScheduledRide(rideId, customerId);
    } catch (e) {
      emit(ScheduledRidesError(e.toString()));
    }
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    for (final id in b) {
      if (!setA.contains(id)) return false;
    }
    return true;
  }

  RideModel? _firstActiveRide(List<RideModel> rides) {
    for (final ride in rides) {
      final status = ride.status.toLowerCase();
      if (status == 'requested' ||
          status == 'accepted' ||
          status == 'arrived_pickup' ||
          status == 'picked_up' ||
          status == 'in_progress') {
        return ride;
      }
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _customerSub?.cancel();
    await _ridesSub?.cancel();
    return super.close();
  }
}
