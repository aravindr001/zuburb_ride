import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../utils/routes_api_config.dart';

class RoutesApiClient {
  final http.Client _client;

  RoutesApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<int?> computeDrivingDistanceMeters({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final apiKey = await RoutesApiConfig.resolveApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) return null;

    final uri = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.distanceMeters',
      },
      body: jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint(
          'Routes API failed: HTTP ${response.statusCode} ${response.reasonPhrase}. Body: ${response.body}',
        );
      }
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;

    final distance = first['distanceMeters'];
    if (distance is int) return distance;
    if (distance is num) return distance.round();

    return null;
  }

  void close() {
    _client.close();
  }
}
