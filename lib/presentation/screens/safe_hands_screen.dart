import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:zuburb_ride/bloc/ride/driver_tracking_state.dart';
import 'package:zuburb_ride/bloc/ride/driver_tracking_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_rating_cubit.dart';

import 'rate_guard_screen.dart';

class SafeHandsScreen extends StatelessWidget {
  const SafeHandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocListener<DriverTrackingCubit, DriverTrackingState>(
        listenWhen: (previous, current) => current is DriverTrackingRideCompleted,
        listener: (context, state) {
          final trackingCubit = context.read<DriverTrackingCubit>();

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => RideRatingCubit(
                  rideId: trackingCubit.rideId,
                  riderId: trackingCubit.riderId,
                ),
                child: const RateGuardScreen(),
              ),
            ),
            (route) => false,
          );
        },
        child: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Our Guard will drop you to your desired location',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You are in safe hands',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
