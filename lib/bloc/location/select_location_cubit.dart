import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../repository/places_api_client.dart';
import 'select_location_state.dart';

class SelectLocationCubit extends Cubit<SelectLocationState> {
  final PlacesApiClient _placesApi;
  Timer? _searchDebounce;
  int _searchToken = 0;

  SelectLocationCubit({PlacesApiClient? placesApi})
      : _placesApi = placesApi ?? PlacesApiClient(),
        super(const SelectLocationInitial());

  SelectLocationReady? _coerceReady(SelectLocationState current) {
    if (current is SelectLocationReady) return current;
    if (current is SelectLocationFailure) {
      return SelectLocationReady(
        pickupLocation: current.pickupLocation,
        dropLocation: current.dropLocation,
        markers: current.markers,
        isLoading: current.isLoading,
        permissionDenied: current.permissionDenied,
        pickupQuery: current.pickupQuery,
        dropQuery: current.dropQuery,
        suggestions: current.suggestions,
        isSearching: current.isSearching,
        activeSearchField: current.activeSearchField,
      );
    }
    return null;
  }

  Future<void> init() async {
    emit(
      const SelectLocationReady(
        pickupLocation: null,
        dropLocation: null,
        markers: <Marker>{},
        isLoading: true,
        permissionDenied: false,
        pickupQuery: '',
        dropQuery: '',
        suggestions: <PlaceSuggestion>[],
        isSearching: false,
        activeSearchField: SelectLocationSearchField.drop,
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
            pickupQuery: current.pickupQuery,
            dropQuery: current.dropQuery,
            suggestions: current.suggestions,
            isSearching: false,
            activeSearchField: current.activeSearchField,
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
          pickupQuery: state.pickupQuery,
          dropQuery: state.dropQuery,
          suggestions: state.suggestions,
          isSearching: false,
          activeSearchField: state.activeSearchField,
        ),
      );
    } catch (e) {
      emit(SelectLocationFailure.fromState(state, e.toString()));
    }
  }

  void onMapTap(LatLng position) {
    final current = _coerceReady(state);
    if (current == null) return;

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
        suggestions: const <PlaceSuggestion>[],
        isSearching: false,
        activeSearchField: SelectLocationSearchField.drop,
      ),
    );
  }

  void setActiveSearchField(SelectLocationSearchField field) {
    final current = _coerceReady(state);
    if (current == null) return;
    emit(current.copyWith(activeSearchField: field));
  }

  void onPickupQueryChanged(String query) {
    final current = _coerceReady(state);
    if (current == null) return;

    emit(
      current.copyWith(
        pickupQuery: query,
        activeSearchField: SelectLocationSearchField.pickup,
        isSearching: query.trim().length >= 3,
      ),
    );
    _search(query);
  }

  void onDropQueryChanged(String query) {
    final current = _coerceReady(state);
    if (current == null) return;

    emit(
      current.copyWith(
        dropQuery: query,
        activeSearchField: SelectLocationSearchField.drop,
        isSearching: query.trim().length >= 3,
      ),
    );
    _search(query);
  }

  void _search(String query) {
    final current = _coerceReady(state);
    if (current == null) return;

    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      emit(
        current.copyWith(
          suggestions: const <PlaceSuggestion>[],
          isSearching: false,
        ),
      );
      return;
    }

    final token = ++_searchToken;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final latestReady = _coerceReady(state);
      if (latestReady == null) return;
      if (token != _searchToken) return;

      try {
        final results = await _placesApi.autocomplete(
          input: trimmed,
          locationBias: latestReady.pickupLocation,
        );

        final afterReady = _coerceReady(state);
        if (afterReady == null) return;
        if (token != _searchToken) return;

        emit(
          afterReady.copyWith(
            suggestions: results,
            isSearching: false,
          ),
        );
      } catch (_) {
        final afterReady = _coerceReady(state);
        if (afterReady == null) return;
        if (token != _searchToken) return;
        emit(
          afterReady.copyWith(
            suggestions: const <PlaceSuggestion>[],
            isSearching: false,
          ),
        );
      }
    });
  }

  Future<void> selectSuggestion(PlaceSuggestion suggestion) async {
    final current = _coerceReady(state);
    if (current == null) return;

    emit(
      current.copyWith(
        isSearching: true,
      ),
    );

    try {
      final latLng = await _placesApi.fetchLatLngForPlaceId(suggestion.placeId);
      if (latLng == null) {
        emit(
          current.copyWith(
            isSearching: false,
            suggestions: const <PlaceSuggestion>[],
          ),
        );
        emit(SelectLocationFailure.fromState(state, 'Could not resolve that place.'));
        return;
      }

      final ready = state;
      final readyCoerced = _coerceReady(ready);
      if (readyCoerced == null) return;

      final field = readyCoerced.activeSearchField;
      if (field == SelectLocationSearchField.pickup) {
        final newMarkers = Set<Marker>.from(readyCoerced.markers)
          ..removeWhere((m) => m.markerId.value == 'pickup')
          ..add(
            Marker(
              markerId: const MarkerId('pickup'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Pickup'),
            ),
          );

        emit(
          readyCoerced.copyWith(
            pickupLocation: latLng,
            markers: newMarkers,
            pickupQuery: suggestion.description,
            suggestions: const <PlaceSuggestion>[],
            isSearching: false,
          ),
        );
      } else {
        final newMarkers = Set<Marker>.from(readyCoerced.markers)
          ..removeWhere((m) => m.markerId.value == 'drop')
          ..add(
            Marker(
              markerId: const MarkerId('drop'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Drop'),
            ),
          );

        emit(
          readyCoerced.copyWith(
            dropLocation: latLng,
            markers: newMarkers,
            dropQuery: suggestion.description,
            suggestions: const <PlaceSuggestion>[],
            isSearching: false,
          ),
        );
      }
    } catch (e) {
      emit(SelectLocationFailure.fromState(state, e.toString()));
    }
  }

  void clearSuggestions() {
    final current = _coerceReady(state);
    if (current == null) return;
    if (current.suggestions.isEmpty && !current.isSearching) return;
    emit(
      current.copyWith(
        suggestions: const <PlaceSuggestion>[],
        isSearching: false,
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

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    _placesApi.close();
    return super.close();
  }
}
