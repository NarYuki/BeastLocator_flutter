import 'package:flutter/services.dart';

import '../models/destination.dart';

class NativeBridge {
  static const _channel = MethodChannel('moe.n4tsu.beast/native');

  static Future<void> syncState(Map<String, Object?> values) async {
    try {
      await _channel.invokeMethod<void>('syncState', values);
    } catch (_) {
      // Desktop/web builds and unavailable native extensions are intentionally ignored.
    }
  }

  static Future<bool> playSound(String asset, int priority) async {
    try {
      return await _channel.invokeMethod<bool>('playSound', {
            'asset': asset,
            'priority': priority,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> reverseGeocode(Destination destination) async {
    try {
      return await _channel.invokeMethod<String>('reverseGeocode', {
        'lat': destination.lat,
        'lng': destination.lng,
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> requestAlwaysLocationAuthorization() async {
    try {
      await _channel.invokeMethod<void>('requestAlwaysLocationAuthorization');
    } catch (_) {}
  }

  static Future<void> updateLiveActivity(Map<String, Object?> values) async {
    try {
      await _channel.invokeMethod<void>('updateLiveActivity', values);
    } catch (_) {}
  }

  static Future<void> endLiveActivity() async {
    try {
      await _channel.invokeMethod<void>('endLiveActivity');
    } catch (_) {}
  }
}
