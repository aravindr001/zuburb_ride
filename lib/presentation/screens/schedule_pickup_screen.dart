import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zuburb_ride/bloc/ride/finding_driver_cubit.dart';
import 'package:zuburb_ride/bloc/ride/schedule_pickup_cubit.dart';
import 'package:zuburb_ride/bloc/ride/schedule_pickup_state.dart';
import 'package:zuburb_ride/presentation/screens/finding_driver_screen.dart';

class SchedulePickupScreen extends StatelessWidget {
  final LatLng pickup;
  final LatLng drop;

  const SchedulePickupScreen({
    super.key,
    required this.pickup,
    required this.drop,
  });

  Future<void> _pickDateTime(BuildContext context, SchedulePickupReady state) async {
    final now = DateTime.now();
    final initialDate = state.scheduledAt ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date == null || !context.mounted) return;

    final initialTime = TimeOfDay.fromDateTime(state.scheduledAt ?? now.add(const Duration(hours: 1)));
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time == null || !context.mounted) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (selected.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future time')),
      );
      return;
    }

    await context.read<SchedulePickupCubit>().setScheduled(selected);
  }

  String _formatScheduledAt(DateTime? scheduledAt) {
    if (scheduledAt == null) return 'Select date & time';
    final local = scheduledAt.toLocal();
    final twoDigitMonth = local.month.toString().padLeft(2, '0');
    final twoDigitDay = local.day.toString().padLeft(2, '0');
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    return '$twoDigitDay/$twoDigitMonth/${local.year} $hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SchedulePickupCubit, SchedulePickupState>(
      listener: (context, state) {
        if (state is SchedulePickupBooked) {
          if (state.bookedForNow) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => FindingDriverCubit(rideId: state.rideId)..init(),
                  child: FindingDriverScreen(rideId: state.rideId),
                ),
              ),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scheduled ride created successfully')),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          return;
        }

        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final ready = state is SchedulePickupReady
            ? state
            : (state is SchedulePickupBooked
                ? SchedulePickupReady(
                    isScheduled: state.isScheduled,
                    scheduledAt: state.scheduledAt,
                    riders: state.riders,
                    selectedRiderId: state.selectedRiderId,
                    isLoadingRiders: state.isLoadingRiders,
                    isSubmitting: state.isSubmitting,
                    errorMessage: state.errorMessage,
                  )
                : SchedulePickupReady.initial());

        return Scaffold(
          appBar: AppBar(title: const Text('Select Pickup Time')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'When should pickup happen?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Now')),
                    ButtonSegment<bool>(value: true, label: Text('Scheduled')),
                  ],
                  selected: {ready.isScheduled},
                  onSelectionChanged: (selection) async {
                    final isScheduled = selection.first;
                    if (!isScheduled) {
                      await context.read<SchedulePickupCubit>().setNow();
                      return;
                    }
                    await _pickDateTime(context, ready.copyWith(isScheduled: true));
                  },
                ),
                const SizedBox(height: 12),
                if (ready.isScheduled)
                  InkWell(
                    onTap: () => _pickDateTime(context, ready),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_formatScheduledAt(ready.scheduledAt)),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Available riders (${ready.riders.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ready.isLoadingRiders && ready.riders.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () => context.read<SchedulePickupCubit>().loadRiders(),
                          child: ready.riders.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 160),
                                    Center(child: Text('No riders found')),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: ready.riders.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final rider = ready.riders[index];
                                    final isSelected = ready.selectedRiderId == rider.riderId;
                                    return ListTile(
                                      selected: isSelected,
                                      onTap: () => context.read<SchedulePickupCubit>().selectRider(rider.riderId),
                                      leading: CircleAvatar(child: Text('${index + 1}')),
                                      title: Text(rider.name),
                                      subtitle: Text('${rider.distanceKm.toStringAsFixed(2)} km away'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.star, size: 18),
                                          const SizedBox(width: 4),
                                          Text(rider.rating.toStringAsFixed(1)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: ready.isSubmitting
                        ? null
                        : () => context.read<SchedulePickupCubit>().confirmBooking(),
                    child: ready.isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(ready.isScheduled ? 'Schedule Ride' : 'Book Ride Now'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
