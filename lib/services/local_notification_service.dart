import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zuburb_ride/models/ride_model.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showScheduledRideStarting(RideModel ride) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        'scheduled_ride_activation',
        'Scheduled Ride Activation',
        channelDescription: 'Notifications when scheduled rides start',
        importance: Importance.max,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final pickup = ride.pickupAddress.trim().isEmpty ? 'your pickup point' : ride.pickupAddress;
      await _plugin.show(
        ride.id.hashCode,
        'Your scheduled ride is starting!',
        'Pickup: $pickup',
        details,
      );
    } catch (e) {
      debugPrint('Local notification failed: $e');
    }
  }
}
