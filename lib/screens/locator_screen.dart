import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:live_activities/live_activities.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/destination.dart';
import '../services/app_store.dart';
import '../services/native_bridge.dart';
import '../theme/beast_palette.dart';
import '../utils/geo_utils.dart';
import 'locator_widgets.dart';
import 'settings_screen.dart';

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
  bool _arrivalSoundPlayed = false;
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
    if (store == null) return;
    final current = _currentLocation ?? store.lastKnownLocation;
    if (current == null ||
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
      await _syncNativeState();
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
    unawaited(_primeCurrentPosition());
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings(),
        ).listen(
          _onPosition,
          onError: (_) => _setUnavailable('位置情報の取得を開始できませんでした'),
        );
  }

  Future<void> _primeCurrentPosition() async {
    final store = _store;
    if (store == null || store.debugDistanceOverrideEnabled) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      ).timeout(const Duration(seconds: 12));
      await _onPosition(position);
    } catch (_) {
      // The continuous stream remains active; this only primes widgets quickly.
    }
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
    final current = _currentLocation ?? store.lastKnownLocation;
    double? liveDistance = distanceMeters;
    String? liveDirection = direction;
    double? liveRotation;
    if (current != null && current.isValid && target.isValid) {
      final bearing = GeoUtils.bearingDegrees(current, target);
      liveDistance ??= GeoUtils.distanceMeters(current, target);
      liveDirection ??= GeoUtils.cardinalFromBearing(bearing);
      liveRotation = GeoUtils.normalizeRotation(
        bearing - _headingDegrees - _arrowOffsetDegrees,
      );
    }

    final arrived = store.isDestinationAnswered;
    final hasWidgetData = liveDistance != null && liveDirection != null;
    final nativeState = <String, Object?>{
      'debug_dest_override_enabled': store.isDestinationOverrideEnabled,
      'debug_dest_override_lat': target.lat,
      'debug_dest_override_lng': target.lng,
      'dest_answered': arrived,
      'arrival_rearm_required': store.arrivalRearmRequired,
      'arrival_name': store.arrivalName,
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
      'widget_has_data': hasWidgetData,
      'widget_distance': hasWidgetData
          ? (arrived ? '到着' : GeoUtils.formatDistance(liveDistance))
          : null,
      'widget_direction': hasWidgetData
          ? (arrived ? 'こ↑こ↓' : '方角: $liveDirection')
          : null,
      'widget_rotation': hasWidgetData
          ? (arrived ? 0.0 : liveRotation ?? 0.0)
          : null,
      'widget_arrived': arrived,
    };
    if (current != null && current.isValid) {
      nativeState['last_lat'] = current.lat;
      nativeState['last_lng'] = current.lng;
    }
    await NativeBridge.syncState(nativeState);

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
    final direction = GeoUtils.cardinalFromBearing(bearing);

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
    final enteredArrivalRange =
        distanceMeters <= _arrivalThresholdMeters &&
        (previous == null || previous > _arrivalThresholdMeters);
    if (distanceMeters > _arrivalThresholdMeters + 25) {
      _arrivalSoundPlayed = false;
    } else if (store.arrivalSoundEnabled &&
        !_arrivalSoundPlayed &&
        enteredArrivalRange) {
      _arrivalSoundPlayed = true;
      unawaited(_playSound('audio/arrival_0km.wav', priority: 4));
    }

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
    if (store.arrivalSoundEnabled && !_arrivalSoundPlayed) {
      _arrivalSoundPlayed = true;
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
    _arrivalSoundPlayed = false;
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
    final colors = BeastPalette.of(context);
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
        decoration: BoxDecoration(gradient: colors.mainGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    if (maskVisible)
                      MainIconButton(
                        tooltip: manualMask ? '距離表示の丸めをオフにする' : '距離表示の丸めをオンにする',
                        onPressed: _toggleMask,
                        icon: Icon(
                          manualMask ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    const SizedBox(width: 8),
                    MainIconButton(
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
                      ? ArrivalView(
                          key: const ValueKey('arrival'),
                          destination: target,
                          name: store?.arrivalName,
                          onReset: _resetArrival,
                        )
                      : LocatorView(
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
