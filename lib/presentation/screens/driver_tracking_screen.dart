import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zuburb_ride/bloc/ride/driver_tracking_cubit.dart';
import 'package:zuburb_ride/bloc/ride/driver_tracking_state.dart';

import 'package:zuburb_ride/bloc/ride/ride_rating_cubit.dart';

import 'safe_hands_screen.dart';
import 'rate_guard_screen.dart';

class DriverTrackingScreen extends StatefulWidget {
  final String rideId;

  const DriverTrackingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
  GoogleMapController? _mapController;
  bool _cameraFittedOnce = false;
  bool _navigatedToSafeHands = false;
  bool _navigatedToRating = false;

  void _goToRating() {
    if (_navigatedToRating) return;
    _navigatedToRating = true;
    if (!mounted) return;

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
  }

  void _goToSafeHands() {
    if (_navigatedToSafeHands) return;
    _navigatedToSafeHands = true;

    if (!mounted) return;

    final cubit = context.read<DriverTrackingCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const SafeHandsScreen(),
        ),
      ),
    );
  }

  Future<void> _fitCamera(LatLng a, LatLng b) async {
    if (_mapController == null || _cameraFittedOnce) return;
    _cameraFittedOnce = true;

    final southWest = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final northEast = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: southWest, northeast: northEast),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<DriverTrackingCubit, DriverTrackingState>(
        listener: (context, state) {
        if (state is DriverTrackingReady) {
          _fitCamera(state.rider, state.pickup);

          if (state.isPickupOtpVerified) {
            _goToSafeHands();
            return;
          }
        }

        if (state is DriverTrackingPickupVerified) {
          _goToSafeHands();
          return;
        }

        if (state is DriverTrackingRideCompleted) {
          _goToRating();
          return;
        }

        if (state is DriverTrackingCancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );

          Navigator.popUntil(context, (route) => route.isFirst);
        }

        if (state is DriverTrackingFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
        },
        builder: (context, state) {
        final markers = state is DriverTrackingReady ? state.markers : <Marker>{};
        final initialTarget = state is DriverTrackingReady ? state.pickup : const LatLng(20.5937, 78.9629);

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Driver Tracking'),
          ),
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: state is DriverTrackingReady ? 14 : 5,
                ),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;

                  if (state is DriverTrackingReady) {
                    _fitCamera(state.rider, state.pickup);
                  }
                },
              ),
              if (state is! DriverTrackingReady && state is! DriverTrackingCancelled)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              if (state is DriverTrackingCancelled)
                Center(
                  child: Text(state.message),
                ),
              if (state is DriverTrackingReady &&
                  (state.isNearPickup || (state.pickupOtp?.isNotEmpty ?? false)))
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _NearPickupPanel(state: state),
                    ),
                  ),
                ),
            ],
          ),
        );
        },
      ),
    );
  }
}

class _NearPickupPanel extends StatelessWidget {
  final DriverTrackingReady state;

  const _NearPickupPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final otp = state.pickupOtp;
    if (otp == null || otp.isEmpty) {
      return const Text('Driver is near your pickup location\nWaiting for OTP…');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Driver is near your pickup location'),
        const SizedBox(height: 8),
        const Text('Show this OTP to your driver:'),
        const SizedBox(height: 8),
        Text(
          otp,
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
        ),
      ],
    );
  }
}
