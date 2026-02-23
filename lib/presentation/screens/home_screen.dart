import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/bloc/auth/auth_status_cubit.dart';
import 'package:zuburb_ride/bloc/location/select_location_cubit.dart';
import 'package:zuburb_ride/bloc/ride/customer_ride_session_cubit.dart';
import 'package:zuburb_ride/bloc/ride/customer_ride_session_state.dart';
import 'package:zuburb_ride/bloc/ride/driver_tracking_cubit.dart';
import 'package:zuburb_ride/bloc/ride/finding_driver_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_confirmation_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_rating_cubit.dart';
import 'select_location_screen.dart';
import 'driver_tracking_screen.dart';
import 'finding_driver_screen.dart';
import 'safe_hands_screen.dart';
import 'rate_guard_screen.dart';
import 'ride_confirmation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastNavigationKey;
  late final CustomerRideSessionCubit _sessionCubit;
  bool _didReadRouteArgs = false;
  bool _skipAutoResumeRideOnce = false;

  @override
  void initState() {
    super.initState();
    _sessionCubit = CustomerRideSessionCubit()..init();
  }

  @override
  void dispose() {
    _sessionCubit.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadRouteArgs) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['skipAutoResumeRide'] == true) {
      _skipAutoResumeRideOnce = true;
    }
    _didReadRouteArgs = true;
  }

  void _navigateForSessionState(CustomerRideSessionState state) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;

    if (_skipAutoResumeRideOnce) {
      if (state is CustomerRideSessionIdle || state is CustomerRideSessionFailure) {
        _skipAutoResumeRideOnce = false;
      }
      return;
    }

    final navigationKey = switch (state) {
      CustomerRideSessionFindingDriver s => 'finding:${s.rideId}',
      CustomerRideSessionTracking s => 'tracking:${s.rideId}:${s.riderId}',
      CustomerRideSessionSafeHands s => 'safe:${s.rideId}:${s.riderId}',
      CustomerRideSessionRating s => 'rating:${s.rideId}:${s.riderId}',
      _ => null,
    };

    if (navigationKey == null) {
      _lastNavigationKey = null;
      return;
    }

    if (navigationKey == _lastNavigationKey) return;
    _lastNavigationKey = navigationKey;

    Widget screen;
    if (state is CustomerRideSessionFindingDriver) {
      screen = BlocProvider(
        create: (_) => FindingDriverCubit(rideId: state.rideId)..init(),
        child: FindingDriverScreen(rideId: state.rideId),
      );
    } else if (state is CustomerRideSessionTracking) {
      screen = BlocProvider(
        create: (_) => DriverTrackingCubit(
          rideId: state.rideId,
          riderId: state.riderId,
          pickup: state.pickup,
        )..init(),
        child: DriverTrackingScreen(rideId: state.rideId),
      );
    } else if (state is CustomerRideSessionSafeHands) {
      screen = BlocProvider(
        create: (_) => DriverTrackingCubit(
          rideId: state.rideId,
          riderId: state.riderId,
          pickup: state.pickup,
        )..init(),
        child: const SafeHandsScreen(),
      );
    } else if (state is CustomerRideSessionRating) {
      screen = BlocProvider(
        create: (_) => RideRatingCubit(
          rideId: state.rideId,
          riderId: state.riderId,
        ),
        child: const RateGuardScreen(),
      );
    } else {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _sessionCubit,
      child: BlocListener<CustomerRideSessionCubit, CustomerRideSessionState>(
        listener: (context, state) {
          _navigateForSessionState(state);

          if (state is CustomerRideSessionFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text("ZUBURB RIDE", style: TextStyle(letterSpacing: 6)),
            actions: [
              TextButton(
                onPressed: () => context.read<AuthStatusCubit>().signOut(),
                child: const Text("Logout"),
              )
            ],
          ),
          body: Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => SelectLocationCubit()..init(),
                      child: const SelectLocationScreen(),
                    ),
                  ),
                );

                if (!context.mounted) return;

                if (result != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => RideConfirmationCubit(
                          pickup: result['pickup'],
                          drop: result['drop'],
                        )..init(),
                        child: RideConfirmationScreen(
                          pickup: result['pickup'],
                          drop: result['drop'],
                        ),
                      ),
                    ),
                  );
                }
              },
              child: const Text("Where to?", style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}
