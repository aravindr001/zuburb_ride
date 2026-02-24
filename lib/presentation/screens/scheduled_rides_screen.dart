import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:zuburb_ride/bloc/ride/driver_tracking_cubit.dart';
import 'package:zuburb_ride/bloc/ride/scheduled_rides_cubit.dart';
import 'package:zuburb_ride/bloc/ride/scheduled_rides_state.dart';
import 'package:zuburb_ride/models/ride_model.dart';
import 'package:zuburb_ride/presentation/screens/driver_tracking_screen.dart';

class ScheduledRidesScreen extends StatelessWidget {
  const ScheduledRidesScreen({super.key});

  bool _canCancelScheduledRide(RideModel ride) {
    if (ride.status.toLowerCase() != 'scheduled') return false;
    final scheduledAt = ride.scheduledAt;
    if (scheduledAt == null) return false;

    final cutoff = scheduledAt.toLocal().subtract(const Duration(hours: 1));
    return DateTime.now().isBefore(cutoff);
  }

  void _navigateToTrackingIfActivated(BuildContext context, ScheduledRideActivated state) {
    final riderId = state.activeRide.riderId.trim();
    final pickup = state.activeRide.pickup;
    if (riderId.isEmpty || pickup == null) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => DriverTrackingCubit(
            rideId: state.activeRide.id,
            riderId: riderId,
            pickup: pickup,
          )..init(),
          child: DriverTrackingScreen(rideId: state.activeRide.id),
        ),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    ScheduledRidesCubit cubit,
    RideModel ride,
  ) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel scheduled ride?'),
        content: const Text('This ride will be marked as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;
    await cubit.cancelScheduledRide(ride.id);
  }

  Color _statusColor(BuildContext context, String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'cancelled') return Colors.red.shade100;
    if (normalized == 'completed') return Colors.green.shade100;
    if (normalized == 'scheduled') return Colors.blue.shade100;
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Rides'),
      ),
      body: BlocConsumer<ScheduledRidesCubit, ScheduledRidesState>(
        listener: (context, state) {
          if (state is ScheduledRideActivated) {
            _navigateToTrackingIfActivated(context, state);
          }
        },
        builder: (context, state) {
          if (state is ScheduledRidesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ScheduledRidesError) {
            return Center(child: Text(state.message));
          }

          if (state is! ScheduledRidesLoaded) {
            return const SizedBox.shrink();
          }

          final rides = state.upcoming;
          if (rides.isEmpty) {
            return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No scheduled rides',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
          }

          final formatter = DateFormat('dd MMM yyyy, hh:mm a');
          final cubit = context.read<ScheduledRidesCubit>();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              final dateTimeLabel = ride.scheduledAt != null
                  ? formatter.format(ride.scheduledAt!.toLocal())
                  : 'Time not set';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateTimeLabel,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(context, ride.status),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(ride.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Pickup: ${ride.pickupAddress}'),
                      const SizedBox(height: 4),
                      Text('Drop: ${ride.dropAddress}'),
                      const SizedBox(height: 4),
                      Text(
                        'Distance: ${ride.distanceKm?.toStringAsFixed(2) ?? 'N/A'} km',
                      ),
                      const SizedBox(height: 8),
                      if (ride.status.toLowerCase() == 'scheduled')
                        if (_canCancelScheduledRide(ride))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _confirmCancel(context, cubit, ride),
                              child: const Text('Cancel'),
                            ),
                          )
                        else
                          const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Cannot cancel within 1 hour of ride'),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
