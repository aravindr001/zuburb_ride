import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zuburb_ride/bloc/ride/ride_confirmation_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_confirmation_state.dart';
import 'package:zuburb_ride/bloc/ride/schedule_pickup_cubit.dart';
import 'package:zuburb_ride/presentation/screens/schedule_pickup_screen.dart';

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
      listener: (context, state) {},
      builder: (context, state) {
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
                  'Distance: ${state.distanceKm.toStringAsFixed(2)} km'
                  '${state.isRouteDistance ? ' (route)' : ' (straight-line)'}',
                  style: const TextStyle(fontSize: 18),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider(
                            create: (_) => SchedulePickupCubit(
                              pickup: pickup,
                              drop: drop,
                              distanceKm: state.distanceKm,
                            )..init(),
                            child: SchedulePickupScreen(
                              pickup: pickup,
                              drop: drop,
                            ),
                          ),
                        ),
                      );
                    },
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
