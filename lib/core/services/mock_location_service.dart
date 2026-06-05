import 'package:flutter/services.dart';

class MockLocationService {
  static const MethodChannel _channel = MethodChannel('mock_location_channel');

  static Future<bool> isMockLocation(double lat, double lon) async {
    final result = await _channel.invokeMethod('isMockLocation', {
      'lat': lat,
      'lon': lon,
    });
    return result as bool;
  }
}
