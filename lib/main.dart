import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:live_activities/live_activities.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'beast_localizations.dart';

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

void main() {
  runApp(const BeastLocatorApp());
}

class BeastLocatorApp extends StatelessWidget {
  const BeastLocatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0057D8);
    return MaterialApp(
      title: 'BeastLocator',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en'), Locale('zh', 'CN')],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FAFF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const LocatorScreen(),
    );
  }
}

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
    await _prefs.remove('last_lat');
    await _prefs.remove('last_lng');
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

class GeoUtils {
  static const _earthRadiusMeters = 6371000.0;

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

class LocatorScreen extends StatefulWidget {
  const LocatorScreen({super.key});

  @override
  State<LocatorScreen> createState() => _LocatorScreenState();
}

class _LocatorScreenState extends State<LocatorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _arrowOffsetDegrees = 45.0;
  static const _arrivalThresholdMeters = 50.0;
  static const _distanceMaskStepKm = 100;
  static const _distance114514Meters = 114514.0;
  static const _distance114514ToleranceMeters = 80.0;
  static const _liveActivityCustomId = 'beast-locator-navigation';
  static const _appGroupId = 'group.moe.n4tsu.beast';

  AppStore? _store;
  Destination? _currentLocation;
  double _headingDegrees = 0;
  bool _hasHeadingSample = false;
  String _statusText = '現在地を取得中...';
  String _directionText = '方角: --';
  double _arrowRotationDegrees = 0;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  late final AnimationController _loadingController;
  double? _previousSoundDistanceMeters;
  int? _lastIntervalSoundBucket;
  bool _distance114514SoundPlayed = false;
  bool _isAppBackgrounded = false;
  final LiveActivities _liveActivities = LiveActivities();
  Map<String, dynamic>? _latestLiveActivityData;
  Timer? _liveActivityShoutTimer;
  Timer? _liveActivityFlushTimer;
  bool _isLiveActivityShoutVisible = false;
  bool _liveActivitySending = false;
  DateTime? _lastLiveActivitySentAt;
  Map<String, dynamic>? _pendingLiveActivityData;
  int _liveActivitySequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _compassSub?.cancel();
    _liveActivityShoutTimer?.cancel();
    _liveActivityFlushTimer?.cancel();
    unawaited(_liveActivities.dispose());
    _loadingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppBackgrounded = false;
      _startLocationUpdates();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final wasBackgrounded = _isAppBackgrounded;
      _isAppBackgrounded = true;
      if (!wasBackgrounded) {
        unawaited(_updateLiveActivityFromCurrentLocation());
      }
    }
  }

  Future<void> _updateLiveActivityFromCurrentLocation() async {
    final store = _store;
    final current = _currentLocation;
    if (store == null ||
        current == null ||
        !store.liveUpdateEnabled ||
        store.isDestinationAnswered) {
      return;
    }
    final target = store.destination;
    if (!current.isValid || !target.isValid) return;
    final distance = GeoUtils.distanceMeters(current, target);
    final direction = GeoUtils.cardinalFromBearing(
      GeoUtils.bearingDegrees(current, target),
    );
    await _syncNativeState(
      distanceMeters: distance,
      direction: direction,
      forceLiveActivityUpdate: true,
    );
  }

  Future<void> _initialize() async {
    final store = await AppStore.load();
    _store = store;
    _currentLocation = store.lastKnownLocation;
    await _liveActivities.init(
      appGroupId: _appGroupId,
      requestAndroidNotificationPermission: false,
    );
    await Permission.notification.request();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await NativeBridge.endLiveActivity();
      await _liveActivities.endAllActivities();
    }
    await _syncNativeState();
    if (mounted) setState(() {});
    _startCompass();
    await _startLocationUpdates();
    if (mounted && !store.welcomeCompleted) {
      unawaited(_showWelcome());
    }
  }

  Future<void> _showWelcome() async {
    final store = _store;
    if (store == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BeastLocatorへようこそ'),
        content: const Text(
          'このアプリがあれば、野獣邸までの方向を瞬時に把握できます\n\n'
          '⚠️このアプリは、個人的に制作したファン向けのアプリです。'
          'コートコーポレーション本社周辺での迷惑行為を推奨、および助長するものではありません。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('はじめる'),
          ),
        ],
      ),
    );
    await store.setWelcomeCompleted(true);
  }

  void _startCompass() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      final store = _store;
      if (heading == null || store == null || !heading.isFinite) return;
      final next = GeoUtils.normalize360(heading);
      _headingDegrees = store.compassSmoothingEnabled && _hasHeadingSample
          ? GeoUtils.smoothAngle(_headingDegrees, next, 0.15)
          : next;
      _hasHeadingSample = true;
      unawaited(_syncNativeState());
      _refreshComputedUi();
    });
  }

  Future<void> _startLocationUpdates() async {
    final store = _store;
    if (store == null) return;

    if (store.debugDistanceOverrideEnabled) {
      _currentLocation = store.lastKnownLocation;
      _refreshComputedUi();
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setUnavailable('端末の位置情報がオフです。設定を確認してください');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        permission == LocationPermission.whileInUse) {
      await NativeBridge.requestAlwaysLocationAuthorization();
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse) {
        unawaited(_showAlwaysLocationPrompt());
      }
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setUnavailable('位置情報の権限が必要です');
      return;
    }

    await _positionSub?.cancel();
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      await _onPosition(last);
    }
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings(),
        ).listen(
          _onPosition,
          onError: (_) => _setUnavailable('位置情報の取得を開始できませんでした'),
        );
  }

  LocationSettings _locationSettings() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 1,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
  }

  Future<void> _showAlwaysLocationPrompt() async {
    if (!mounted) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('常に許可が必要です'),
        content: const Text(
          'ウィジェット更新や到達通知を正しく動かすため、次の画面で「権限」を開き、'
          '位置情報を「常に許可」に変更してください',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('設定へ進む'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _onPosition(Position position) async {
    final store = _store;
    if (store == null || store.debugDistanceOverrideEnabled) return;
    final location = Destination(position.latitude, position.longitude);
    _currentLocation = location;
    await store.setLastKnownLocation(location);
    await _syncNativeState();
    _refreshComputedUi();
  }

  Future<void> _syncNativeState({
    double? distanceMeters,
    String? direction,
    bool forceLiveActivityUpdate = false,
  }) async {
    final store = _store;
    if (store == null) return;
    final target = store.destination;
    final current = _currentLocation;
    await NativeBridge.syncState({
      'debug_dest_override_enabled': store.isDestinationOverrideEnabled,
      'debug_dest_override_lat': target.lat,
      'debug_dest_override_lng': target.lng,
      'dest_answered': store.isDestinationAnswered,
      'arrival_rearm_required': store.arrivalRearmRequired,
      'arrival_name': store.arrivalName,
      'last_lat': current?.lat,
      'last_lng': current?.lng,
      'last_heading': _headingDegrees,
      'debug_distance_override_enabled': store.debugDistanceOverrideEnabled,
      'arrival_notification_enabled': store.arrivalNotificationEnabled,
      'live_update_enabled': store.liveUpdateEnabled,
      'live_update_start_distance_meters': store.liveUpdateStartDistanceMeters,
      'background_location_update_enabled':
          store.backgroundLocationUpdateEnabled,
      'widget_bearing_mode': store.widgetBearingMode,
      'legacy_compass_mode_enabled': store.legacyCompassModeEnabled,
      'screenshot_warning_enabled': store.screenshotWarningEnabled,
      'non_japanese_language_enabled': store.nonJapaneseLanguageEnabled,
      'arrival_sound_enabled': store.arrivalSoundEnabled,
      'distance_114514_sound_enabled': store.distance114514SoundEnabled,
      'distance_interval_sound_enabled': store.distanceIntervalSoundEnabled,
      'distance_interval_sound_meters': store.distanceIntervalMeters,
    });
    double? liveDistance = distanceMeters;
    String? liveDirection = direction;
    double? liveRotation;
    if (current != null && current.isValid && target.isValid) {
      final bearing = GeoUtils.bearingDegrees(current, target);
      liveDistance ??= GeoUtils.distanceMeters(current, target);
      liveDirection ??= GeoUtils.cardinalFromBearing(
        GeoUtils.normalize360(bearing - _headingDegrees),
      );
      liveRotation = GeoUtils.normalizeRotation(
        bearing - _headingDegrees - _arrowOffsetDegrees,
      );
    }

    if (liveDistance != null &&
        liveDirection != null &&
        store.liveUpdateEnabled &&
        (_isAppBackgrounded || forceLiveActivityUpdate)) {
      final start = store.liveUpdateStartDistanceMeters.toDouble();
      final progress = liveDistance >= start
          ? 0
          : (((start - liveDistance) / (start - 50)).clamp(0, 1) * 100).round();
      await _updateLiveActivity({
        'distance': GeoUtils.formatDistance(liveDistance),
        'direction': liveDirection,
        'rotation': liveRotation ?? 0.0,
        'progress': progress,
        'arrived': store.isDestinationAnswered,
        'shout': false,
      });
    }
  }

  Future<void> _updateLiveActivity(Map<String, dynamic> data) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    _latestLiveActivityData = Map<String, dynamic>.from(data);
    if (_isLiveActivityShoutVisible && data['shout'] != true) return;
    _scheduleLiveActivityData(data);
  }

  void _scheduleLiveActivityData(Map<String, dynamic> data) {
    _pendingLiveActivityData = Map<String, dynamic>.from(data);
    if (_liveActivityFlushTimer?.isActive == true) return;

    final lastSent = _lastLiveActivitySentAt;
    final elapsed = lastSent == null
        ? const Duration(seconds: 1)
        : DateTime.now().difference(lastSent);
    final wait = elapsed >= const Duration(milliseconds: 650)
        ? Duration.zero
        : const Duration(milliseconds: 650) - elapsed;
    _liveActivityFlushTimer = Timer(wait, _flushLiveActivityData);
  }

  Future<void> _flushLiveActivityData() async {
    _liveActivityFlushTimer?.cancel();
    _liveActivityFlushTimer = null;
    if (_liveActivitySending) {
      _liveActivityFlushTimer = Timer(
        const Duration(milliseconds: 120),
        _flushLiveActivityData,
      );
      return;
    }

    final data = _pendingLiveActivityData;
    if (data == null) return;
    _pendingLiveActivityData = null;
    _liveActivitySending = true;
    _lastLiveActivitySentAt = DateTime.now();
    final payload = Map<String, Object?>.from(data)
      ..['activityId'] = _liveActivityCustomId
      ..['sequence'] = ++_liveActivitySequence;
    try {
      await _liveActivities.createOrUpdateActivity(
        _liveActivityCustomId,
        payload,
        removeWhenAppIsKilled: false,
        iOSEnableRemoteUpdates: false,
      );
    } finally {
      _liveActivitySending = false;
    }

    if (_pendingLiveActivityData != null) {
      _liveActivityFlushTimer = Timer(
        const Duration(milliseconds: 650),
        _flushLiveActivityData,
      );
    }
  }

  Future<void> _flashLiveActivityShout() async {
    final normalData = _latestLiveActivityData;
    if (normalData == null || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _liveActivityShoutTimer?.cancel();
    _isLiveActivityShoutVisible = true;
    _scheduleLiveActivityData({...normalData, 'shout': true});
    _liveActivityShoutTimer = Timer(const Duration(seconds: 5), () {
      _isLiveActivityShoutVisible = false;
      final latest = _latestLiveActivityData;
      if (latest != null) {
        _scheduleLiveActivityData({...latest, 'shout': false});
      }
    });
  }

  void _setUnavailable(String text) {
    if (!mounted) return;
    setState(() {
      _statusText = text;
      _directionText = '';
      _currentLocation = null;
    });
    if (!_loadingController.isAnimating) _loadingController.repeat();
  }

  void _refreshComputedUi() {
    final store = _store;
    final current = _currentLocation;
    if (store == null || current == null) {
      if (mounted) setState(() {});
      return;
    }
    final target = store.destination;
    if (!current.isValid || !target.isValid) return;

    if (store.isDestinationAnswered) {
      _loadingController.stop();
      if (mounted) setState(() {});
      return;
    }

    final distance = GeoUtils.distanceMeters(current, target);
    final bearing = GeoUtils.bearingDegrees(current, target);
    final relative = GeoUtils.normalizeRotation(
      bearing - _headingDegrees - _arrowOffsetDegrees,
    );
    final masked = store.manualDistanceMaskEnabled;
    final direction = GeoUtils.cardinalFromBearing(
      GeoUtils.normalize360(bearing - _headingDegrees),
    );

    _handleSoundTriggers(distance);
    if (mounted) {
      setState(() {
        _arrowRotationDegrees = relative;
        _statusText = _formatMainDistance(distance, masked);
        _directionText = masked ? '方角: --' : '方角: $direction';
      });
    }
    unawaited(_syncNativeState(distanceMeters: distance, direction: direction));
    _loadingController.stop();

    if (store.arrivalRearmRequired && distance > _arrivalThresholdMeters) {
      unawaited(store.setArrivalRearmRequired(false));
    }
    if (!store.arrivalRearmRequired && distance <= _arrivalThresholdMeters) {
      unawaited(_markArrived(target));
    }
  }

  String _formatMainDistance(double distanceMeters, bool masked) {
    if (!masked) return GeoUtils.formatDistance(distanceMeters);
    final distanceKm = distanceMeters / 1000;
    final maskedKm = distanceKm <= _distanceMaskStepKm
        ? _distanceMaskStepKm
        : (distanceKm / _distanceMaskStepKm).ceil() * _distanceMaskStepKm;
    return '$maskedKm km';
  }

  void _handleSoundTriggers(double distanceMeters) {
    final store = _store;
    if (store == null || !distanceMeters.isFinite) return;

    final previous = _previousSoundDistanceMeters;
    final upper114514 = _distance114514Meters + _distance114514ToleranceMeters;
    final lower114514 = _distance114514Meters - _distance114514ToleranceMeters;
    final isInside114514Range =
        distanceMeters >= lower114514 && distanceMeters <= upper114514;
    final crossed114514Range =
        previous != null &&
        previous > upper114514 &&
        distanceMeters < lower114514;

    if (!store.distance114514SoundEnabled) {
      _distance114514SoundPlayed = false;
    } else if (!_distance114514SoundPlayed &&
        (isInside114514Range || crossed114514Range)) {
      _distance114514SoundPlayed = true;
      unawaited(_playSound('audio/distance_114514km.mp3', priority: 3));
    } else if (distanceMeters > upper114514 + 500) {
      _distance114514SoundPlayed = false;
    }

    if (store.distanceIntervalSoundEnabled && !store.isDestinationAnswered) {
      final interval = store.distanceIntervalMeters.clamp(100, 5000);
      final currentBucket = (distanceMeters / interval).floor();
      final previousBucket = _lastIntervalSoundBucket;
      if (previousBucket != null && currentBucket < previousBucket) {
        unawaited(_flashLiveActivityShout());
        unawaited(
          _playSound('audio/distance_interval_kankaku.mp3', priority: 1),
        );
      }
      _lastIntervalSoundBucket = currentBucket;
    } else {
      _lastIntervalSoundBucket = null;
    }

    _previousSoundDistanceMeters = distanceMeters;
  }

  Future<void> _playSound(String asset, {required int priority}) async {
    await NativeBridge.playSound(asset, priority);
  }

  Future<void> _markArrived(Destination target) async {
    final store = _store;
    if (store == null || store.isDestinationAnswered) return;
    await store.setDestinationAnswered(true);
    final resolved = await NativeBridge.reverseGeocode(target);
    await store.setArrivalName(
      resolved?.isNotEmpty == true
          ? resolved!
          : '${target.lat.toStringAsFixed(6)}, ${target.lng.toStringAsFixed(6)}',
    );
    if (store.arrivalSoundEnabled) {
      await _playSound('audio/arrival_0km.wav', priority: 2);
    }
    if (mounted) setState(() {});
    await _syncNativeState();
    await _updateLiveActivity({
      'distance': '到着',
      'direction': 'こ↑こ↓',
      'rotation': 0.0,
      'progress': 100,
      'arrived': true,
      'shout': false,
    });
  }

  Future<void> _resetArrival() async {
    final store = _store;
    if (store == null) return;
    await store.setDestinationAnswered(false);
    await store.setArrivalRearmRequired(true);
    _previousSoundDistanceMeters = null;
    _lastIntervalSoundBucket = null;
    _distance114514SoundPlayed = false;
    _liveActivityShoutTimer?.cancel();
    _liveActivityFlushTimer?.cancel();
    _isLiveActivityShoutVisible = false;
    await NativeBridge.endLiveActivity();
    await _liveActivities.endAllActivities();
    _latestLiveActivityData = null;
    await _syncNativeState();
    _refreshComputedUi();
  }

  Future<void> _toggleMask() async {
    final store = _store;
    if (store == null) return;
    await store.setManualDistanceMaskEnabled(!store.manualDistanceMaskEnabled);
    await _syncNativeState();
    _refreshComputedUi();
  }

  Future<void> _openSettings() async {
    final store = _store;
    if (store == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => SettingsScreen(store: store)),
    );
    _startCompass();
    await _startLocationUpdates();
    _refreshComputedUi();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final target = store?.destination ?? AppStore.defaultDestination;
    final arrived = store?.isDestinationAnswered ?? false;
    final maskVisible = store?.distanceMaskButtonVisible ?? true;
    final manualMask = store?.manualDistanceMaskEnabled ?? false;
    final rotation = _currentLocation == null && !arrived
        ? _loadingController
        : AlwaysStoppedAnimation(_arrowRotationDegrees / 360);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6FAFF), Color(0xFFEDF4FF), Color(0xFFEAF7F1)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    if (maskVisible)
                      IconButton.filledTonal(
                        tooltip: manualMask ? '距離表示の丸めをオフにする' : '距離表示の丸めをオンにする',
                        onPressed: _toggleMask,
                        icon: Icon(
                          manualMask ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '設定',
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
              ),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: arrived
                      ? _ArrivalView(
                          key: const ValueKey('arrival'),
                          destination: target,
                          name: store?.arrivalName,
                          onReset: _resetArrival,
                        )
                      : _LocatorView(
                          key: const ValueKey('locator'),
                          rotation: rotation,
                          distanceText: _statusText,
                          directionText: _directionText,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocatorView extends StatelessWidget {
  const _LocatorView({
    super.key,
    required this.rotation,
    required this.distanceText,
    required this.directionText,
  });

  final Animation<double> rotation;
  final String distanceText;
  final String directionText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: rotation,
            child: Image.asset(
              'assets/images/yjsnpi.png',
              width: 208,
              height: 208,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          FittedBox(
            child: Text(
              distanceText,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            directionText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

class _ArrivalView extends StatelessWidget {
  const _ArrivalView({
    super.key,
    required this.destination,
    required this.name,
    required this.onReset,
  });

  final Destination destination;
  final String? name;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'こ↑こ↓',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name?.isNotEmpty == true ? name! : '正解位置を確認中...',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '緯度 ${destination.lat.toStringAsFixed(6)} / 経度 ${destination.lng.toStringAsFixed(6)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: FilledButton(
              onPressed: onReset,
              child: const Text('到達状態をリセットする'),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppStore get store => widget.store;

  String _formatMeters(int meters) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '$meters m';
  }

  @override
  Widget build(BuildContext context) {
    final destination = store.destination;
    return _BeastSettingsScaffold(
      title: '設定',
      subtitle: '通知表示やウィジェット設定を調整できます',
      children: [
        _SettingsCard(
          title: '現在の目的地',
          subtitle: '野獣邸の座標です。この目的地を案内します',
          children: [
            _BodyText(
              '緯度 ${destination.lat.toStringAsFixed(6)} / 経度 ${destination.lng.toStringAsFixed(6)}',
              monospace: true,
            ),
            _BodyText(store.isDestinationOverrideEnabled ? 'デバッグ上書き中' : '初期値'),
          ],
        ),
        _SettingsCard(
          title: 'コンパス',
          subtitle: '方位表示に関する設定',
          children: [
            _SettingSwitchRow(
              title: 'コンパスを従来方式にする',
              subtitle:
                  'コンパスの測定方式を従来の方式にします\n'
                  'コンパスの動作が不安定な場合にお試しください',
              value: store.legacyCompassModeEnabled,
              onChanged: (value) async {
                await store.setLegacyCompassModeEnabled(value);
                setState(() {});
              },
            ),
            _SettingSwitchRow(
              title: '野獣先輩の動きを平滑化',
              subtitle: 'ONにすると矢印の動きが滑らかになります',
              value: store.compassSmoothingEnabled,
              onChanged: (value) async {
                await store.setCompassSmoothingEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        _SettingsCard(
          title: 'ウィジェット設定',
          subtitle: 'ホーム画面ウィジェットの方位表示',
          children: [
            _RadioOption(
              title: '絶対方位（北基準）',
              subtitle: '',
              value: 'absolute',
              groupValue: store.widgetBearingMode,
              onChanged: _setWidgetBearingMode,
            ),
            _RadioOption(
              title: '相対方位（端末の向き基準）',
              subtitle: '',
              value: 'relative',
              groupValue: store.widgetBearingMode,
              onChanged: _setWidgetBearingMode,
            ),
          ],
        ),
        _SettingsCard(
          title: '身バレ防止機能',
          subtitle: '位置の特定につながる項目に関する設定',
          children: [
            _SettingSwitchRow(
              title: '身バレ防止ボタンを表示',
              subtitle:
                  'メイン画面右上に、距離や方角に関する表示を'
                  '大雑把な表示に切り替えるボタンを表示します',
              value: store.distanceMaskButtonVisible,
              onChanged: (value) async {
                await store.setDistanceMaskButtonVisible(value);
                if (!value) await store.setManualDistanceMaskEnabled(false);
                setState(() {});
              },
            ),
            _SettingSwitchRow(
              title: '身バレ防止警告を表示',
              subtitle:
                  'リスクを忘れないために、スクリーンショットを検知した際に'
                  '特定リスクがある旨の警告を表示します',
              value: store.screenshotWarningEnabled,
              onChanged: (value) async {
                await store.setScreenshotWarningEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        _SettingsCard(
          title: 'バックグラウンド更新',
          subtitle: 'バックグラウンド動作に関する設定',
          children: [
            _SettingSwitchRow(
              title: 'バックグラウンドで位置を更新',
              subtitle:
                  'バックグラウンドアプリとして動作して位置を更新するため、'
                  '通知が来やすくなります',
              value: store.backgroundLocationUpdateEnabled,
              onChanged: (value) async {
                await store.setBackgroundLocationUpdateEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        _SettingsCard(
          title: '通知',
          subtitle: '目的地に近づいた際の通知',
          children: [
            _SettingSwitchRow(
              title: '到達時に通知を表示',
              subtitle: '50m以内まで到達した際に、目的地に到着した旨を通知で送信します',
              value: store.arrivalNotificationEnabled,
              onChanged: (value) async {
                await store.setArrivalNotificationEnabled(value);
                setState(() {});
              },
            ),
            _SettingSwitchRow(
              title: '到達進捗を通知で表示',
              subtitle:
                  '目的地から一定の距離まで近づくと、'
                  'ライブアップデートにより進捗を通知で知らせます',
              value: store.liveUpdateEnabled,
              onChanged: (value) async {
                await store.setLiveUpdateEnabled(value);
                setState(() {});
              },
            ),
            _SettingSliderRow(
              title: '進捗表示を開始する距離',
              valueLabel: _formatMeters(store.liveUpdateStartDistanceMeters),
              value: store.liveUpdateStartDistanceMeters.toDouble(),
              min: 200,
              max: 5000,
              divisions: 48,
              enabled: store.liveUpdateEnabled,
              onChanged: (value) async {
                await store.setLiveUpdateStartDistanceMeters(value.round());
                setState(() {});
              },
            ),
          ],
        ),
        _SettingsCard(
          title: '実験的機能',
          subtitle: '将来的に追加される機能の設定',
          children: [
            _FullWidthButton(
              icon: Icons.science,
              label: '実験的機能の設定を開く',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ExperimentalSettingsScreen(store: store),
                  ),
                );
                setState(() {});
              },
            ),
          ],
        ),
        _SettingsCard(
          title: 'このアプリについて',
          subtitle: 'アプリ情報とオープンソースライセンスを表示します',
          children: [
            _FullWidthButton(
              icon: Icons.info,
              label: '表示する',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
        _SettingsCard(
          title: 'バージョン',
          subtitle: 'BeastLocator / Version 1.0.0',
          children: [
            _FullWidthButton(
              icon: Icons.bug_report,
              label: store.debugMenuVisible ? 'デバッグメニューを非表示' : 'デバッグメニューを表示',
              tonal: true,
              onPressed: () async {
                await store.setDebugMenuVisible(!store.debugMenuVisible);
                setState(() {});
              },
            ),
          ],
        ),
        if (store.debugMenuVisible) ...[
          _SettingsCard(
            title: 'デバッグ',
            subtitle: '目的地や現在距離を上書きします',
            children: [
              _FullWidthButton(
                icon: Icons.flag,
                label: '現在のセッションを到達とする',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await store.setDestinationAnswered(true);
                  await store.setArrivalName(
                    '${store.destination.lat.toStringAsFixed(6)}, ${store.destination.lng.toStringAsFixed(6)}',
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('現在のセッションを到達にしました')),
                    );
                  }
                },
              ),
              _FullWidthButton(
                icon: Icons.speed,
                label: '目的地までの距離を書き換え',
                outlined: true,
                onPressed: _showDebugDistanceDialog,
              ),
              _FullWidthButton(
                icon: Icons.refresh,
                label: '目的地までの距離をリセット',
                outlined: true,
                onPressed: () async {
                  await store.clearDebugDistanceOverride();
                  setState(() {});
                },
              ),
              _FullWidthButton(
                icon: Icons.edit_location,
                label: '目的地座標を編集',
                outlined: true,
                onPressed: _showDestinationDialog,
              ),
              _FullWidthButton(
                icon: Icons.home,
                label: '目的地を初期値に戻す',
                outlined: true,
                onPressed: () async {
                  await store.clearDestinationOverride();
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _setWidgetBearingMode(String value) async {
    await store.setWidgetBearingMode(value);
    setState(() {});
  }

  Future<void> _showDebugDistanceDialog() async {
    final controller = TextEditingController();
    final meters = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目的地までの距離を書き換え'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '例: 1000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (meters == null || meters < 0 || meters > 20000000) return;
    final fakeLocation = GeoUtils.destinationAt(store.destination, meters, 180);
    await store.setDebugDistanceOverride(fakeLocation);
    setState(() {});
  }

  Future<void> _showDestinationDialog() async {
    final target = store.destination;
    final latController = TextEditingController(
      text: target.lat.toStringAsFixed(6),
    );
    final lngController = TextEditingController(
      text: target.lng.toStringAsFixed(6),
    );
    final destination = await showDialog<Destination>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目的地を編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: '緯度'),
            ),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: '経度'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latController.text.trim());
              final lng = double.tryParse(lngController.text.trim());
              if (lat == null || lng == null) {
                Navigator.pop(context);
              } else {
                Navigator.pop(context, Destination(lat, lng));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (destination == null || !destination.isValid) return;
    await store.setDestinationOverride(destination);
    setState(() {});
  }
}

class ExperimentalSettingsScreen extends StatefulWidget {
  const ExperimentalSettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ExperimentalSettingsScreen> createState() =>
      _ExperimentalSettingsScreenState();
}

class _ExperimentalSettingsScreenState
    extends State<ExperimentalSettingsScreen> {
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return _BeastSettingsScaffold(
      title: '実験的機能',
      subtitle: '将来的に追加される機能です',
      children: [
        _SettingsCard(
          title: '言語設定',
          subtitle: 'ローカライズの設定',
          children: [
            _SettingSwitchRow(
              title: '日本語以外の言語も使用可能にする',
              subtitle: '現在は簡体中国語、英語に対応しています',
              value: store.nonJapaneseLanguageEnabled,
              onChanged: (value) async {
                await store.setNonJapaneseLanguageEnabled(value);
                setState(() {});
              },
            ),
            _FullWidthButton(
              icon: Icons.language,
              label: '言語設定に進む',
              outlined: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('端末の言語設定から変更してください')),
                );
              },
            ),
          ],
        ),
        _SettingsCard(
          title: 'コンパス',
          subtitle: '方位表示に関する設定',
          children: [
            _SettingSwitchRow(
              title: '野獣先輩の動きを平滑化',
              subtitle: 'ONにすることで、野獣先輩の動きを多少滑らかにすることができます',
              value: store.compassSmoothingEnabled,
              onChanged: (value) async {
                await store.setCompassSmoothingEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        _SettingsCard(
          title: 'サウンド再生 (実験的)',
          subtitle:
              'いずれかをONにすると、位置情報を常に監視するようになるため'
              'バッテリーの減りが早くなる可能性があります',
          children: [
            _SettingSwitchRow(
              title: '到着時のこ↑こ↓サウンド',
              subtitle: '目的地まで50m以内に入った際に こ↑こ↓ と音声が流れます',
              value: store.arrivalSoundEnabled,
              onChanged: (value) async {
                await store.setArrivalSoundEnabled(value);
                setState(() {});
              },
            ),
            _SettingSwitchRow(
              title: '114.514kmで呼び込み先輩を再生',
              subtitle:
                  '距離が114.514kmに到達した際に呼び込み先輩の音楽を再生します\n'
                  '⚠️この音楽は一時停止できないため、公共の場で鳴らないよう注意してください',
              value: store.distance114514SoundEnabled,
              onChanged: (value) async {
                await store.setDistance114514SoundEnabled(value);
                setState(() {});
              },
            ),
            _FullWidthButton(
              icon: Icons.open_in_new,
              label: '元動画を開く',
              outlined: true,
              onPressed: () => launchUrl(
                Uri.parse('https://www.nicovideo.jp/watch/sm33266722'),
              ),
            ),
            _SettingSwitchRow(
              title: '一定間隔ごとに咆哮を再生',
              subtitle:
                  '目的地まで一定の距離近づくたびに野獣の咆哮を再生します\n'
                  '⚠️この音声は一時停止できないため、公共の場で鳴らないよう注意してください',
              value: store.distanceIntervalSoundEnabled,
              onChanged: (value) async {
                await store.setDistanceIntervalSoundEnabled(value);
                setState(() {});
              },
            ),
            _SettingSliderRow(
              title: '再生する間隔',
              valueLabel: _formatMeters(store.distanceIntervalMeters),
              value: store.distanceIntervalMeters.toDouble(),
              min: 100,
              max: 5000,
              divisions: 49,
              enabled: store.distanceIntervalSoundEnabled,
              onChanged: (value) async {
                await store.setDistanceIntervalMeters(value.round());
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  String _formatMeters(int meters) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '$meters m';
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BeastSettingsScaffold(
      title: 'このアプリについて',
      children: [
        _SettingsCard(
          title: 'BeastLocator',
          subtitle: 'Version 1.0.0',
          children: [
            Center(child: Image.asset('assets/images/icon.png', height: 96)),
            const _BodyText(
              'このアプリは、個人的に制作したファンメイドアプリです。'
              'コートコーポレーション本社周辺での迷惑行為を推奨、および助長するものではありません。',
            ),
          ],
        ),
        const Row(
          children: [
            Expanded(
              child: _CompactInfoCard(title: '開発チャネル', value: 'Flutter'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _CompactInfoCard(title: 'バージョン', value: '1.0.0'),
            ),
          ],
        ),
        _SettingsCard(
          title: 'サポート',
          subtitle: '関連リンク',
          children: [
            _FullWidthButton(
              icon: Icons.public,
              label: 'サポートサイトを開く',
              outlined: true,
              onPressed: () => launchUrl(Uri.parse('https://linkserver.jp/')),
            ),
            _FullWidthButton(
              icon: Icons.open_in_new,
              label: 'X (Twitter) を開く',
              outlined: true,
              onPressed: () => launchUrl(Uri.parse('https://x.com/Link_2011A')),
            ),
          ],
        ),
        const _SettingsCard(
          title: 'オープンソースライセンス',
          subtitle: '利用ライブラリ',
          children: [_BodyText('利用しているパッケージのライセンスを一覧で表示できます。')],
        ),
        _FullWidthButton(
          icon: Icons.article,
          label: 'ライセンス一覧を表示',
          outlined: true,
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'BeastLocator',
            applicationVersion: '1.0.0',
            applicationIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset('assets/images/icon.png', height: 72),
            ),
          ),
        ),
      ],
    );
  }
}

class _BeastSettingsScaffold extends StatelessWidget {
  const _BeastSettingsScaffold({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF4FF), Color(0xFFF8FBFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: beastText(context, '戻る'),
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF102B4D),
                    fixedSize: const Size(48, 48),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                beastText(context, title),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102B4D),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  beastText(context, subtitle!),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF52677F),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFAFC2DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            beastText(context, title),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102B4D),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              beastText(context, subtitle!),
              style: const TextStyle(fontSize: 12, color: Color(0xFF5E7189)),
            ),
          ],
          const SizedBox(height: 12),
          ..._withSpacing(children),
        ],
      ),
    );
  }

  static List<Widget> _withSpacing(List<Widget> children) {
    final spaced = <Widget>[];
    for (final child in children) {
      if (spaced.isNotEmpty) spaced.add(const SizedBox(height: 10));
      spaced.add(child);
    }
    return spaced;
  }
}

class _SettingSwitchRow extends StatelessWidget {
  const _SettingSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                beastText(context, title),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF172A44),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                beastText(context, subtitle),
                style: const TextStyle(fontSize: 12, color: Color(0xFF62758C)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SettingSliderRow extends StatelessWidget {
  const _SettingSliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF172A44) : const Color(0xFF8A98AA);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                beastText(context, title),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF62758C),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beastText(context, title),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172A44),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      beastText(context, subtitle),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF62758C),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullWidthButton extends StatelessWidget {
  const _FullWidthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.tonal = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            beastText(context, label),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (outlined) {
      return OutlinedButton(style: style, onPressed: onPressed, child: child);
    }
    if (tonal) {
      return FilledButton.tonal(
        style: style,
        onPressed: onPressed,
        child: child,
      );
    }
    return FilledButton(style: style, onPressed: onPressed, child: child);
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text, {this.monospace = false});

  final String text;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Text(
      beastText(context, text),
      style: TextStyle(
        fontSize: 13,
        height: 1.45,
        fontFamily: monospace ? 'monospace' : null,
        color: const Color(0xFF334155),
      ),
    );
  }
}

class _CompactInfoCard extends StatelessWidget {
  const _CompactInfoCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFAFC2DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF62758C)),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102B4D),
            ),
          ),
        ],
      ),
    );
  }
}
