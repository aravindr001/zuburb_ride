import 'package:google_maps_flutter/google_maps_flutter.dart';

sealed class SelectLocationState {
  final LatLng? pickupLocation;
  final LatLng? dropLocation;
  final Set<Marker> markers;
  final bool isLoading;
  final bool permissionDenied;

  const SelectLocationState({
    required this.pickupLocation,
    required this.dropLocation,
    required this.markers,
    required this.isLoading,
    required this.permissionDenied,
  });

  bool get canConfirm => pickupLocation != null && dropLocation != null;
}

final class SelectLocationInitial extends SelectLocationState {
  const SelectLocationInitial()
      : super(
          pickupLocation: null,
          dropLocation: null,
          markers: const <Marker>{},
          isLoading: true,
          permissionDenied: false,
        );
}

final class SelectLocationReady extends SelectLocationState {
  const SelectLocationReady({
    required super.pickupLocation,
    required super.dropLocation,
    required super.markers,
    required super.isLoading,
    required super.permissionDenied,
  });

  SelectLocationReady copyWith({
    LatLng? pickupLocation,
    LatLng? dropLocation,
    Set<Marker>? markers,
    bool? isLoading,
    bool? permissionDenied,
  }) {
    return SelectLocationReady(
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      markers: markers ?? this.markers,
      isLoading: isLoading ?? this.isLoading,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

final class SelectLocationFailure extends SelectLocationState {
  final String message;

  const SelectLocationFailure(this.message)
      : super(
          pickupLocation: null,
          dropLocation: null,
          markers: const <Marker>{},
          isLoading: false,
          permissionDenied: false,
        );
}
