import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zuburb_ride/bloc/auth/auth_status_cubit.dart';
import 'package:zuburb_ride/bloc/location/select_location_cubit.dart';
import 'package:zuburb_ride/bloc/ride/customer_ride_session_cubit.dart';
import 'package:zuburb_ride/bloc/ride/customer_ride_session_state.dart';
import 'package:zuburb_ride/bloc/ride/driver_tracking_cubit.dart';
import 'package:zuburb_ride/bloc/ride/finding_driver_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_confirmation_cubit.dart';
import 'package:zuburb_ride/bloc/ride/ride_rating_cubit.dart';
import 'package:zuburb_ride/bloc/ride/scheduled_rides_cubit.dart';
import 'package:zuburb_ride/bloc/ride/scheduled_rides_state.dart';
import 'package:zuburb_ride/repository/ride_repository.dart';
import 'select_location_screen.dart';
import 'driver_tracking_screen.dart';
import 'finding_driver_screen.dart';
import 'safe_hands_screen.dart';
import 'rate_guard_screen.dart';
import 'ride_confirmation_screen.dart';
import 'scheduled_rides_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastNavigationKey;
  late final CustomerRideSessionCubit _sessionCubit;
  late final ScheduledRidesCubit _scheduledRidesCubit;
  bool _didReadRouteArgs = false;
  bool _skipAutoResumeRideOnce = false;
  String? _lastScheduledActivationRideId;

  @override
  void initState() {
    super.initState();
    _sessionCubit = CustomerRideSessionCubit()..init();

    final customerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _scheduledRidesCubit = ScheduledRidesCubit(
      rideRepository: context.read<RideRepository>(),
      customerId: customerId,
    )..init();
  }

  @override
  void dispose() {
    _sessionCubit.close();
    _scheduledRidesCubit.close();
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

  void _navigateForScheduledActivation(ScheduledRideActivated state) {
    if (!mounted) return;
    if (state.activeRide.id == _lastScheduledActivationRideId) return;
    _lastScheduledActivationRideId = state.activeRide.id;

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

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sessionCubit),
        BlocProvider.value(value: _scheduledRidesCubit),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<CustomerRideSessionCubit, CustomerRideSessionState>(
            listener: (context, state) {
              _navigateForSessionState(state);

              if (state is CustomerRideSessionFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
            },
          ),
          BlocListener<ScheduledRidesCubit, ScheduledRidesState>(
            listener: (context, state) {
              if (state is ScheduledRideActivated) {
                _navigateForScheduledActivation(state);
              }
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text("ZUBURB RIDE", style: TextStyle(letterSpacing: 6)),
          ),
          drawer: Drawer(
            child: SafeArea(
              child: Column(
                children: [
                  const DrawerHeader(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'Menu',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: BlocBuilder<ScheduledRidesCubit, ScheduledRidesState>(
                      builder: (context, state) {
                        var upcomingCount = 0;
                        if (state is ScheduledRidesLoaded) {
                          upcomingCount = state.upcoming.length;
                        }

                        final icon = const Icon(Icons.event_note);
                        if (upcomingCount <= 0) return icon;

                        return Badge(
                          label: Text('$upcomingCount'),
                          child: icon,
                        );
                      },
                    ),
                    title: const Text('Scheduled Rides'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: _scheduledRidesCubit,
                            child: const ScheduledRidesScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      context.read<AuthStatusCubit>().signOut();
                    },
                  ),
                ],
              ),
            ),
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
