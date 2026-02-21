import 'package:flutter_test/flutter_test.dart';
import 'package:zuburb_ride/utils/location_utils.dart';

void main() {
  test('calculateDistance returns a positive number', () {
    final km = calculateDistance(12.9716, 77.5946, 13.0827, 80.2707);
    expect(km, greaterThan(0));
  });

  test('getBounds returns a valid min/max range', () {
    final bounds = getBounds(12.9716, 77.5946, 10);
    expect(bounds['minLat'], lessThan(bounds['maxLat']!));
    expect(bounds['minLng'], lessThan(bounds['maxLng']!));
  });
}
