import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RoutesApiConfig {
  /// Optional: Provide at build/run time via:
  /// `--dart-define=MAPS_API_KEY=...` or `--dart-define=ROUTES_API_KEY=...`
  static const String _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
  static const String _routesApiKey = String.fromEnvironment('ROUTES_API_KEY');

  static const MethodChannel _channel = MethodChannel('zuburb/native_config');

  static String? _cachedKey;
  static bool _attemptedNativeLookup = false;

  static Future<String?> resolveApiKey() async {
    if (_cachedKey != null && _cachedKey!.trim().isNotEmpty) return _cachedKey;

    final fromDefine = _mapsApiKey.trim().isNotEmpty ? _mapsApiKey : _routesApiKey;
    if (fromDefine.trim().isNotEmpty) {
      _cachedKey = fromDefine;
      return _cachedKey;
    }

    if (kIsWeb) return null;
    if (_attemptedNativeLookup) return null;
    _attemptedNativeLookup = true;

    try {
      final key = await _channel.invokeMethod<String>('getMapsApiKey');
      if (key != null && key.trim().isNotEmpty) {
        _cachedKey = key;
      }
      return _cachedKey;
    } catch (_) {
      return null;
    }
  }
}
