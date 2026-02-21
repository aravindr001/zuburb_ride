import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zuburb_ride/bloc/ride/ride_confirmation_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_confirmation_state.dart';
import 'package:zuburb_ride/presentation/screens/finding_driver_screen.dart';
import 'package:zuburb_ride/bloc/ride/finding_driver_cubit.dart';

class RideConfirmationScreen extends StatelessWidget {
  final LatLng pickup;
  final LatLng drop;

  const RideConfirmationScreen({
    super.key,
    required this.pickup,
    required this.drop,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RideConfirmationCubit, RideConfirmationState>(
      listener: (context, state) {
        if (state is RideConfirmationBooked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride booked')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => FindingDriverCubit(rideId: state.rideId)..init(),
                child: FindingDriverScreen(rideId: state.rideId),
              ),
            ),
          );
        }

        if (state is RideConfirmationNoRiders) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No riders available')),
          );
        }

        if (state is RideConfirmationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is RideConfirmationSubmitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Confirm Ride')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pickup',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${pickup.latitude}, ${pickup.longitude}'),
                const SizedBox(height: 20),
                const Text(
                  'Drop',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${drop.latitude}, ${drop.longitude}'),
                const SizedBox(height: 20),
                Text(
                  'Distance: ${state.distanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(fontSize: 18),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => context.read<RideConfirmationCubit>().confirmRide(),
                    child: const Text('Confirm Ride'),
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
