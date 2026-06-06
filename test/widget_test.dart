import 'package:flutter_test/flutter_test.dart';

import 'package:beast_locator/main.dart';

void main() {
  test('GeoUtils calculates a sane distance and bearing', () {
    const from = Destination(35.0, 139.0);
    const to = Destination(35.01, 139.0);

    final distance = GeoUtils.distanceMeters(from, to);
    final bearing = GeoUtils.bearingDegrees(from, to);

    expect(distance, greaterThan(1000));
    expect(distance, lessThan(1200));
    expect(bearing, closeTo(0, 0.5));
  });
}
