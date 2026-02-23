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
  LatLng? _lastAnimatedDrop;
  late final TextEditingController _pickupController;
  late final TextEditingController _dropController;
  late final FocusNode _pickupFocus;
  late final FocusNode _dropFocus;

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController();
    _dropController = TextEditingController();
    _pickupFocus = FocusNode();
    _dropFocus = FocusNode();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SelectLocationCubit, SelectLocationState>(
      listener: (context, state) {
        if (state is SelectLocationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }

        // Don't force-update the controller while the user is typing.
        // (This can break IME/composition and make typing appear to "not show".)
        if (!_pickupFocus.hasFocus && _pickupController.text != state.pickupQuery) {
          _pickupController.text = state.pickupQuery;
          _pickupController.selection = TextSelection.fromPosition(
            TextPosition(offset: _pickupController.text.length),
          );
        }

        if (!_dropFocus.hasFocus && _dropController.text != state.dropQuery) {
          _dropController.text = state.dropQuery;
          _dropController.selection = TextSelection.fromPosition(
            TextPosition(offset: _dropController.text.length),
          );
        }

        final pickup = state.pickupLocation;
        if (pickup != null && pickup != _lastAnimatedPickup) {
          _lastAnimatedPickup = pickup;
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(pickup, 15),
          );
        }

        final drop = state.dropLocation;
        if (drop != null && drop != _lastAnimatedDrop) {
          _lastAnimatedDrop = drop;
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(drop, 15),
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
                onTap: (pos) {
                  FocusScope.of(context).unfocus();
                  context.read<SelectLocationCubit>().onMapTap(pos);
                },
                markers: state.markers,
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _pickupController,
                          focusNode: _pickupFocus,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: state.pickupLocation != null &&
                                    state.pickupQuery.trim().isEmpty
                                ? 'Current location'
                                : 'Pickup location',
                            prefixIcon: const Icon(Icons.my_location),
                            suffixIcon: IconButton(
                              onPressed: _pickupController.text.trim().isEmpty
                                  ? null
                                  : () {
                                      _pickupController.clear();
                                      context
                                          .read<SelectLocationCubit>()
                                          .onPickupQueryChanged('');
                                      _pickupFocus.requestFocus();
                                    },
                              icon: const Icon(Icons.clear),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onTap: () => context
                              .read<SelectLocationCubit>()
                              .setActiveSearchField(SelectLocationSearchField.pickup),
                          onChanged: context.read<SelectLocationCubit>().onPickupQueryChanged,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _dropController,
                          focusNode: _dropFocus,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search destination',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              onPressed: _dropController.text.trim().isEmpty
                                  ? null
                                  : () {
                                      _dropController.clear();
                                      context
                                          .read<SelectLocationCubit>()
                                          .onDropQueryChanged('');
                                      _dropFocus.requestFocus();
                                    },
                              icon: const Icon(Icons.clear),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onTap: () => context
                              .read<SelectLocationCubit>()
                              .setActiveSearchField(SelectLocationSearchField.drop),
                          onChanged: context.read<SelectLocationCubit>().onDropQueryChanged,
                        ),
                      ),
                      if (state.isSearching)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: LinearProgressIndicator(),
                        ),
                      if (state.suggestions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Material(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: state.suggestions.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final suggestion = state.suggestions[index];
                                  return ListTile(
                                    title: Text(
                                      suggestion.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      if (state.activeSearchField ==
                                          SelectLocationSearchField.pickup) {
                                        _pickupController.text = suggestion.description;
                                        _pickupController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _pickupController.text.length),
                                        );
                                      } else {
                                        _dropController.text = suggestion.description;
                                        _dropController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _dropController.text.length),
                                        );
                                      }
                                      context
                                          .read<SelectLocationCubit>()
                                          .selectSuggestion(suggestion);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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