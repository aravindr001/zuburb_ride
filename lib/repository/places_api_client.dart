import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../utils/routes_api_config.dart';

@immutable
class PlaceSuggestion {
  final String placeId;
  final String description;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
  });
}

class PlacesApiClient {
  final http.Client _client;

  PlacesApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    LatLng? locationBias,
    String? types,
  }) async {
    final apiKey = await RoutesApiConfig.resolveApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) return const [];

    final trimmed = input.trim();
    if (trimmed.isEmpty) return const [];

    final params = <String, String>{
      'input': trimmed,
      'key': apiKey,
    };

    // Optional filter. If omitted, Google returns a mix of places including
    // establishments (shops) and addresses.
    final normalizedTypes = types?.trim();
    if (normalizedTypes != null && normalizedTypes.isNotEmpty) {
      params['types'] = normalizedTypes;
    }

    if (locationBias != null) {
      // Radius is in meters.
      params['location'] = '${locationBias.latitude},${locationBias.longitude}';
      params['radius'] = '50000';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint(
          'Places autocomplete failed: HTTP ${response.statusCode} ${response.reasonPhrase}. Body: ${response.body}',
        );
      }
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];

    final status = decoded['status'];
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      if (kDebugMode) {
        debugPrint('Places autocomplete status: $status body: ${response.body}');
      }
      return const [];
    }

    final predictions = decoded['predictions'];
    if (predictions is! List) return const [];

    return predictions
        .whereType<Map>()
        .map((p) {
          final placeId = p['place_id'];
          final description = p['description'];
          if (placeId is! String || description is! String) return null;
          return PlaceSuggestion(placeId: placeId, description: description);
        })
        .whereType<PlaceSuggestion>()
        .toList(growable: false);
  }

  Future<LatLng?> fetchLatLngForPlaceId(String placeId) async {
    final apiKey = await RoutesApiConfig.resolveApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry/location',
        'key': apiKey,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint(
          'Place details failed: HTTP ${response.statusCode} ${response.reasonPhrase}. Body: ${response.body}',
        );
      }
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final status = decoded['status'];
    if (status != 'OK') {
      if (kDebugMode) {
        debugPrint('Place details status: $status body: ${response.body}');
      }
      return null;
    }

    final result = decoded['result'];
    if (result is! Map<String, dynamic>) return null;

    final geometry = result['geometry'];
    if (geometry is! Map<String, dynamic>) return null;

    final location = geometry['location'];
    if (location is! Map<String, dynamic>) return null;

    final lat = location['lat'];
    final lng = location['lng'];
    if (lat is! num || lng is! num) return null;

    return LatLng(lat.toDouble(), lng.toDouble());
  }

  void close() {
    _client.close();
  }
}
