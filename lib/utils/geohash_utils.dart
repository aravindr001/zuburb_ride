import 'package:dart_geohash/dart_geohash.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Returns a geohash precision suitable for a radius query.
///
/// Approximate geohash cell sizes (width/height varies with latitude):
/// 1: ~2500km, 2: ~630km, 3: ~78km, 4: ~20km, 5: ~2.4km, 6: ~0.61km,
/// 7: ~0.076km, 8: ~0.019km
int geohashPrecisionForRadiusKm(double radiusKm) {
  if (radiusKm >= 2500) return 1;
  if (radiusKm >= 630) return 2;
  if (radiusKm >= 78) return 3;
  if (radiusKm >= 20) return 4;
  if (radiusKm >= 2.4) return 5;
  if (radiusKm >= 0.61) return 6;
  if (radiusKm >= 0.076) return 7;
  return 8;
}

/// Returns the 9 geohash prefixes (center + 8 neighbors) for range-prefix
/// queries covering the area around [center].
///
/// Store your rider docs with:
/// - `location`: GeoPoint
/// - `geohash`: String (computed from location)
Set<String> geohashPrefixesForRadius({
  required LatLng center,
  required double radiusKm,
}) {
  final precision = geohashPrecisionForRadiusKm(radiusKm);
  final hasher = GeoHasher();

  // IMPORTANT: dart_geohash encodes (longitude, latitude)
  final centerHash = hasher.encode(
    center.longitude,
    center.latitude,
    precision: precision,
  );

  final neighbors = hasher.neighbors(centerHash).values;
  return neighbors.toSet();
}

/// Firestore prefix query end marker.
String geohashPrefixEnd(String prefix) => '$prefix\uf8ff';
