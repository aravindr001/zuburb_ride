import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'select_location_state.dart';

class SelectLocationCubit extends Cubit<SelectLocationState> {
  SelectLocationCubit() : super(const SelectLocationInitial());

  Future<void> init() async {
    emit(
      const SelectLocationReady(
        pickupLocation: null,
        dropLocation: null,
        markers: <Marker>{},
        isLoading: true,
        permissionDenied: false,
      ),
    );

    try {
      final permission = await _ensurePermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final current = state;
        emit(
          SelectLocationReady(
            pickupLocation: current.pickupLocation,
            dropLocation: current.dropLocation,
            markers: current.markers,
            isLoading: false,
            permissionDenied: true,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final pickup = LatLng(position.latitude, position.longitude);

      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      };

      emit(
        SelectLocationReady(
          pickupLocation: pickup,
          dropLocation: null,
          markers: markers,
          isLoading: false,
          permissionDenied: false,
        ),
      );
    } catch (e) {
      emit(SelectLocationFailure(e.toString()));
    }
  }

  void onMapTap(LatLng position) {
    final current = state;
    if (current is! SelectLocationReady) return;

    final newMarkers = Set<Marker>.from(current.markers)
      ..removeWhere((m) => m.markerId.value == 'drop')
      ..add(
        Marker(
          markerId: const MarkerId('drop'),
          position: position,
          infoWindow: const InfoWindow(title: 'Drop'),
        ),
      );

    emit(
      current.copyWith(
        dropLocation: position,
        markers: newMarkers,
      ),
    );
  }

  Future<LocationPermission> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }
}
