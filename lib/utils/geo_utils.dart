import 'dart:math' as math;

import '../models/destination.dart';

class GeoUtils {
  static const _earthRadiusMeters = 6371000.0;
  static const _distance114514Meters = 114514.0;

  static double distanceMeters(Destination from, Destination to) {
    final lat1 = _rad(from.lat);
    final lat2 = _rad(to.lat);
    final dLat = _rad(to.lat - from.lat);
    final dLng = _rad(to.lng - from.lng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return _earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double bearingDegrees(Destination from, Destination to) {
    final lat1 = _rad(from.lat);
    final lat2 = _rad(to.lat);
    final dLng = _rad(to.lng - from.lng);
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return normalize360(_deg(math.atan2(y, x)));
  }

  static Destination destinationAt(
    Destination from,
    double distanceMeters,
    double bearingDegrees,
  ) {
    final angular = distanceMeters / _earthRadiusMeters;
    final bearing = _rad(bearingDegrees);
    final lat1 = _rad(from.lat);
    final lng1 = _rad(from.lng);
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angular) +
          math.cos(lat1) * math.sin(angular) * math.cos(bearing),
    );
    final lng2 =
        lng1 +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(lat1),
          math.cos(angular) - math.sin(lat1) * math.sin(lat2),
        );
    return Destination(_deg(lat2), ((_deg(lng2) + 540) % 360) - 180);
  }

  static String formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      if ((distanceMeters - _distance114514Meters).abs() < 0.5) {
        return '${(distanceMeters / 1000).toStringAsFixed(3)} km';
      }
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.floor()} m';
  }

  static String cardinalFromBearing(double bearing) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = (((bearing + 22.5) % 360) / 45).floor();
    return dirs[idx];
  }

  static double normalize360(double value) {
    final mod = value % 360;
    return mod < 0 ? mod + 360 : mod;
  }

  static double normalizeRotation(double value) {
    var normalized = value % 360;
    if (normalized > 180) normalized -= 360;
    if (normalized < -180) normalized += 360;
    return normalized.abs() < 0.5 ? 0 : normalized;
  }

  static double smoothAngle(double current, double target, double alpha) {
    final delta = normalizeRotation(target - current);
    return normalize360(current + delta * alpha.clamp(0, 1));
  }

  static double _rad(double value) => value * math.pi / 180;

  static double _deg(double value) => value * 180 / math.pi;
}
