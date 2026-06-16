import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';

class AppStore {
  AppStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppStore> load() async {
    return AppStore(await SharedPreferences.getInstance());
  }

  static const defaultDestination = Destination(35.665554, 139.669717);

  Destination get destination {
    if (_prefs.getBool('debug_dest_override_enabled') == true &&
        _prefs.containsKey('debug_dest_override_lat') &&
        _prefs.containsKey('debug_dest_override_lng')) {
      return Destination(
        _prefs.getDouble('debug_dest_override_lat')!,
        _prefs.getDouble('debug_dest_override_lng')!,
      );
    }
    return defaultDestination;
  }

  Future<void> setDestinationOverride(Destination value) async {
    await _prefs.setBool('debug_dest_override_enabled', true);
    await _prefs.setDouble('debug_dest_override_lat', value.lat);
    await _prefs.setDouble('debug_dest_override_lng', value.lng);
    await setDestinationAnswered(false);
    await _prefs.remove('arrival_name');
  }

  Future<void> clearDestinationOverride() async {
    await _prefs.setBool('debug_dest_override_enabled', false);
    await _prefs.remove('debug_dest_override_lat');
    await _prefs.remove('debug_dest_override_lng');
    await setDestinationAnswered(false);
    await _prefs.remove('arrival_name');
  }

  bool get isDestinationOverrideEnabled =>
      _prefs.getBool('debug_dest_override_enabled') ?? false;

  bool get isDestinationAnswered => _prefs.getBool('dest_answered') ?? false;

  Future<void> setDestinationAnswered(bool value) async {
    await _prefs.setBool('dest_answered', value);
    if (!value) {
      await _prefs.remove('arrival_name');
    }
  }

  bool get arrivalRearmRequired =>
      _prefs.getBool('arrival_rearm_required') ?? false;

  Future<void> setArrivalRearmRequired(bool value) async {
    await _prefs.setBool('arrival_rearm_required', value);
  }

  String? get arrivalName => _prefs.getString('arrival_name');

  Future<void> setArrivalName(String value) =>
      _prefs.setString('arrival_name', value);

  Destination? get lastKnownLocation {
    final lat = _prefs.getDouble('last_lat');
    final lng = _prefs.getDouble('last_lng');
    if (lat == null || lng == null) return null;
    return Destination(lat, lng);
  }

  Future<void> setLastKnownLocation(Destination value) async {
    await _prefs.setDouble('last_lat', value.lat);
    await _prefs.setDouble('last_lng', value.lng);
  }

  bool get debugDistanceOverrideEnabled =>
      _prefs.getBool('debug_distance_override_enabled') ?? false;

  Future<void> setDebugDistanceOverride(Destination value) async {
    await setLastKnownLocation(value);
    await _prefs.setBool('debug_distance_override_enabled', true);
  }

  Future<void> clearDebugDistanceOverride() async {
    await _prefs.setBool('debug_distance_override_enabled', false);
  }

  bool get distanceMaskButtonVisible =>
      _prefs.getBool('distance_mask_button_visible') ?? true;

  Future<void> setDistanceMaskButtonVisible(bool value) =>
      _prefs.setBool('distance_mask_button_visible', value);

  bool get arrivalNotificationEnabled =>
      _prefs.getBool('arrival_notification_enabled') ?? true;

  Future<void> setArrivalNotificationEnabled(bool value) =>
      _prefs.setBool('arrival_notification_enabled', value);

  bool get liveUpdateEnabled => _prefs.getBool('live_update_enabled') ?? true;

  Future<void> setLiveUpdateEnabled(bool value) =>
      _prefs.setBool('live_update_enabled', value);

  int get liveUpdateStartDistanceMeters =>
      _prefs.getInt('live_update_start_distance_meters') ?? 300;

  Future<void> setLiveUpdateStartDistanceMeters(int value) => _prefs.setInt(
    'live_update_start_distance_meters',
    value.clamp(200, 5000),
  );

  bool get backgroundLocationUpdateEnabled =>
      _prefs.getBool('background_location_update_enabled') ?? true;

  Future<void> setBackgroundLocationUpdateEnabled(bool value) =>
      _prefs.setBool('background_location_update_enabled', value);

  String get widgetBearingMode =>
      _prefs.getString('widget_bearing_mode') ?? 'absolute';

  Future<void> setWidgetBearingMode(String value) =>
      _prefs.setString('widget_bearing_mode', value);

  bool get manualDistanceMaskEnabled =>
      _prefs.getBool('manual_distance_mask_enabled') ?? false;

  Future<void> setManualDistanceMaskEnabled(bool value) =>
      _prefs.setBool('manual_distance_mask_enabled', value);

  bool get arrivalSoundEnabled =>
      _prefs.getBool('arrival_sound_enabled') ?? false;

  Future<void> setArrivalSoundEnabled(bool value) =>
      _prefs.setBool('arrival_sound_enabled', value);

  bool get distance114514SoundEnabled =>
      _prefs.getBool('distance_114514_sound_enabled') ?? false;

  Future<void> setDistance114514SoundEnabled(bool value) =>
      _prefs.setBool('distance_114514_sound_enabled', value);

  bool get distanceIntervalSoundEnabled =>
      _prefs.getBool('distance_interval_sound_enabled') ?? false;

  Future<void> setDistanceIntervalSoundEnabled(bool value) =>
      _prefs.setBool('distance_interval_sound_enabled', value);

  int get distanceIntervalMeters =>
      _prefs.getInt('distance_interval_sound_meters') ?? 1000;

  Future<void> setDistanceIntervalMeters(int value) =>
      _prefs.setInt('distance_interval_sound_meters', value.clamp(100, 5000));

  bool get compassSmoothingEnabled =>
      _prefs.getBool('compass_smoothing_enabled') ?? true;

  Future<void> setCompassSmoothingEnabled(bool value) =>
      _prefs.setBool('compass_smoothing_enabled', value);

  bool get legacyCompassModeEnabled =>
      _prefs.getBool('legacy_compass_mode_enabled') ?? false;

  Future<void> setLegacyCompassModeEnabled(bool value) =>
      _prefs.setBool('legacy_compass_mode_enabled', value);

  bool get screenshotWarningEnabled =>
      _prefs.getBool('screenshot_warning_enabled') ?? true;

  Future<void> setScreenshotWarningEnabled(bool value) =>
      _prefs.setBool('screenshot_warning_enabled', value);

  bool get nonJapaneseLanguageEnabled =>
      _prefs.getBool('non_japanese_language_enabled') ?? true;

  Future<void> setNonJapaneseLanguageEnabled(bool value) =>
      _prefs.setBool('non_japanese_language_enabled', value);

  bool get debugMenuVisible => _prefs.getBool('debug_menu_visible') ?? false;

  Future<void> setDebugMenuVisible(bool value) =>
      _prefs.setBool('debug_menu_visible', value);

  bool get welcomeCompleted => _prefs.getBool('welcome_completed') ?? false;

  Future<void> setWelcomeCompleted(bool value) =>
      _prefs.setBool('welcome_completed', value);
}
