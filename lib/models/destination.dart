class Destination {
  const Destination(this.lat, this.lng);

  final double lat;
  final double lng;

  bool get isValid =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;
}
