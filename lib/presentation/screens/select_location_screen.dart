import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:zuburb_ride/bloc/location/select_location_cubit.dart';
import 'package:zuburb_ride/bloc/location/select_location_state.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() =>
      _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  GoogleMapController? _mapController;
  LatLng? _lastAnimatedPickup;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SelectLocationCubit, SelectLocationState>(
      listener: (context, state) {
        if (state is SelectLocationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }

        final pickup = state.pickupLocation;
        if (pickup != null && pickup != _lastAnimatedPickup) {
          _lastAnimatedPickup = pickup;
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(pickup, 15),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Select Destination"),
          ),
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(20.5937, 78.9629),
                  zoom: 5,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;

                  final pickup = state.pickupLocation;
                  if (pickup != null) {
                    _lastAnimatedPickup = pickup;
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(pickup, 15),
                    );
                  }
                },
                onTap: context.read<SelectLocationCubit>().onMapTap,
                markers: state.markers,
              ),
              if (state.isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: state.canConfirm
                      ? () {
                          Navigator.pop(context, {
                            'pickup': state.pickupLocation,
                            'drop': state.dropLocation,
                          });
                        }
                      : null,
                  child: const Text("Confirm Location"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}