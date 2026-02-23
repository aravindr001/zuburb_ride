import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../repository/places_api_client.dart';

enum SelectLocationSearchField {
  pickup,
  drop,
}

sealed class SelectLocationState {
  final LatLng? pickupLocation;
  final LatLng? dropLocation;
  final Set<Marker> markers;
  final bool isLoading;
  final bool permissionDenied;
  final String pickupQuery;
  final String dropQuery;
  final List<PlaceSuggestion> suggestions;
  final bool isSearching;
  final SelectLocationSearchField activeSearchField;

  const SelectLocationState({
    required this.pickupLocation,
    required this.dropLocation,
    required this.markers,
    required this.isLoading,
    required this.permissionDenied,
    required this.pickupQuery,
    required this.dropQuery,
    required this.suggestions,
    required this.isSearching,
    required this.activeSearchField,
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
          pickupQuery: '',
          dropQuery: '',
          suggestions: const <PlaceSuggestion>[],
          isSearching: false,
          activeSearchField: SelectLocationSearchField.drop,
        );
}

final class SelectLocationReady extends SelectLocationState {
  const SelectLocationReady({
    required super.pickupLocation,
    required super.dropLocation,
    required super.markers,
    required super.isLoading,
    required super.permissionDenied,
    required super.pickupQuery,
    required super.dropQuery,
    required super.suggestions,
    required super.isSearching,
    required super.activeSearchField,
  });

  SelectLocationReady copyWith({
    LatLng? pickupLocation,
    LatLng? dropLocation,
    Set<Marker>? markers,
    bool? isLoading,
    bool? permissionDenied,
    String? pickupQuery,
    String? dropQuery,
    List<PlaceSuggestion>? suggestions,
    bool? isSearching,
    SelectLocationSearchField? activeSearchField,
  }) {
    return SelectLocationReady(
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      markers: markers ?? this.markers,
      isLoading: isLoading ?? this.isLoading,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      pickupQuery: pickupQuery ?? this.pickupQuery,
      dropQuery: dropQuery ?? this.dropQuery,
      suggestions: suggestions ?? this.suggestions,
      isSearching: isSearching ?? this.isSearching,
      activeSearchField: activeSearchField ?? this.activeSearchField,
    );
  }
}

final class SelectLocationFailure extends SelectLocationState {
  final String message;

  const SelectLocationFailure({
    required this.message,
    required super.pickupLocation,
    required super.dropLocation,
    required super.markers,
    required super.isLoading,
    required super.permissionDenied,
    required super.pickupQuery,
    required super.dropQuery,
    required super.suggestions,
    required super.isSearching,
    required super.activeSearchField,
  });

  factory SelectLocationFailure.fromState(
    SelectLocationState state,
    String message,
  ) {
    return SelectLocationFailure(
      message: message,
      pickupLocation: state.pickupLocation,
      dropLocation: state.dropLocation,
      markers: state.markers,
      isLoading: false,
      permissionDenied: state.permissionDenied,
      pickupQuery: state.pickupQuery,
      dropQuery: state.dropQuery,
      suggestions: state.suggestions,
      isSearching: false,
      activeSearchField: state.activeSearchField,
    );
  }
}
