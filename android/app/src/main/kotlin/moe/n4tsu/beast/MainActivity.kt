package moe.n4tsu.beast

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncState" -> {
                    @Suppress("UNCHECKED_CAST")
                    val values = call.arguments as? Map<String, Any?>
                    if (values == null) {
                        result.error("bad_args", "syncState requires a map", null)
                    } else {
                        NativeStateStore.sync(this, values)
                        result.success(null)
                    }
                }
                "refreshWidgets" -> {
                    DestinationWidgetProvider.refreshAllWidgets(this)
                    result.success(null)
                }
                "updateBackgroundMonitoring" -> {
                    BackgroundLocationUpdater.updateRegistration(this)
                    result.success(null)
                }
                "playSound" -> {
                    val asset = call.argument<String>("asset")
                    val priority = call.argument<Int>("priority") ?: 0
                    val rawResId = when (asset) {
                        "audio/distance_114514km.mp3" -> R.raw.distance_114514km
                        "audio/arrival_0km.wav" -> R.raw.arrival_0km
                        "audio/distance_interval_kankaku.mp3" -> R.raw.distance_interval_kankaku
                        else -> 0
                    }
                    if (rawResId == 0) {
                        result.success(false)
                    } else {
                        SoundPlaybackService.start(this, rawResId, priority)
                        result.success(true)
                    }
                }
                "reverseGeocode" -> {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    if (lat == null || lng == null) {
                        result.error("bad_args", "lat/lng are required", null)
                    } else {
                        Thread {
                            val resolved = ReverseGeocoder.resolve(this, Destination(lat, lng))
                            runOnUiThread { result.success(resolved) }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
        NotificationHelper.ensureChannel(this)
    }

    companion object {
        private const val CHANNEL = "moe.n4tsu.beast/native"
    }
}
