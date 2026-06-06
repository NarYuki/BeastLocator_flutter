package moe.n4tsu.beast

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Geocoder
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.Locale
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

data class Destination(val lat: Double, val lng: Double)

enum class WidgetBearingMode(val prefValue: String) {
    ABSOLUTE("absolute"),
    RELATIVE("relative");

    companion object {
        fun fromPref(value: String?): WidgetBearingMode {
            return entries.firstOrNull { it.prefValue == value } ?: ABSOLUTE
        }
    }
}

object NativeStateStore {
    private const val PREFS = "beast_native_state"
    private const val DEFAULT_DEST_LAT = 35.665554
    private const val DEFAULT_DEST_LNG = 139.669717

    fun sync(context: Context, values: Map<String, Any?>) {
        val edit = prefs(context).edit()
        values.forEach { (key, value) ->
            when (value) {
                is Boolean -> edit.putBoolean(key, value)
                is Double -> edit.putLong(key, java.lang.Double.doubleToRawLongBits(value))
                is Float -> edit.putFloat(key, value)
                is Int -> edit.putInt(key, value)
                is Long -> edit.putLong(key, value)
                is String -> edit.putString(key, value)
                null -> edit.remove(key)
            }
        }
        edit.apply()
        DestinationWidgetProvider.refreshAllWidgets(context)
        BackgroundLocationUpdater.updateRegistration(context)
        val destination = getDestination(context)
        if (!isDestinationAnswered(context)) {
            GeofenceHelper.registerDestinationGeofence(context, destination)
        } else {
            GeofenceHelper.clearDestinationGeofence(context)
        }
    }

    fun getDestination(context: Context): Destination {
        val p = prefs(context)
        val override = p.getBoolean("debug_dest_override_enabled", false)
        if (override && p.contains("debug_dest_override_lat") && p.contains("debug_dest_override_lng")) {
            return Destination(
                java.lang.Double.longBitsToDouble(p.getLong("debug_dest_override_lat", 0L)),
                java.lang.Double.longBitsToDouble(p.getLong("debug_dest_override_lng", 0L))
            )
        }
        return Destination(DEFAULT_DEST_LAT, DEFAULT_DEST_LNG)
    }

    fun getLastKnownLocation(context: Context): Destination? {
        val p = prefs(context)
        if (!p.contains("last_lat") || !p.contains("last_lng")) return null
        return Destination(
            java.lang.Double.longBitsToDouble(p.getLong("last_lat", 0L)),
            java.lang.Double.longBitsToDouble(p.getLong("last_lng", 0L))
        )
    }

    fun setLastKnownLocation(context: Context, lat: Double, lng: Double) {
        prefs(context).edit()
            .putLong("last_lat", java.lang.Double.doubleToRawLongBits(lat))
            .putLong("last_lng", java.lang.Double.doubleToRawLongBits(lng))
            .apply()
    }

    fun getLastKnownHeading(context: Context): Float? {
        val p = prefs(context)
        if (!p.contains("last_heading")) return null
        return p.getFloat("last_heading", 0f)
    }

    fun setLastKnownHeading(context: Context, heading: Float) {
        prefs(context).edit().putFloat("last_heading", heading).apply()
    }

    fun isDestinationAnswered(context: Context): Boolean =
        prefs(context).getBoolean("dest_answered", false)

    fun setDestinationAnswered(context: Context, answered: Boolean) {
        prefs(context).edit()
            .putBoolean("dest_answered", answered)
            .remove("live_update_anchor_distance_meters")
            .apply()
    }

    fun getArrivalDestinationName(context: Context): String? =
        prefs(context).getString("arrival_name", null)

    fun setArrivalDestinationName(context: Context, name: String) {
        prefs(context).edit().putString("arrival_name", name).apply()
    }

    fun isArrivalRearmRequired(context: Context): Boolean =
        prefs(context).getBoolean("arrival_rearm_required", false)

    fun setArrivalRearmRequired(context: Context, required: Boolean) {
        prefs(context).edit().putBoolean("arrival_rearm_required", required).apply()
    }

    fun isDebugDistanceOverrideEnabled(context: Context): Boolean =
        prefs(context).getBoolean("debug_distance_override_enabled", false)

    fun isLiveUpdateEnabled(context: Context): Boolean =
        prefs(context).getBoolean("live_update_enabled", true)

    fun getLiveUpdateStartDistanceMeters(context: Context): Int =
        prefs(context).getInt("live_update_start_distance_meters", 300)

    fun getLiveUpdateAnchorDistanceMeters(context: Context): Float? {
        val p = prefs(context)
        if (!p.contains("live_update_anchor_distance_meters")) return null
        return p.getFloat("live_update_anchor_distance_meters", 0f)
    }

    fun setLiveUpdateAnchorDistanceMeters(context: Context, value: Float) {
        prefs(context).edit().putFloat("live_update_anchor_distance_meters", value.coerceAtLeast(0f)).apply()
    }

    fun clearLiveUpdateAnchorDistanceMeters(context: Context) {
        prefs(context).edit().remove("live_update_anchor_distance_meters").apply()
    }

    fun isArrivalNotificationEnabled(context: Context): Boolean =
        prefs(context).getBoolean("arrival_notification_enabled", true)

    fun isBackgroundLocationUpdateEnabled(context: Context): Boolean =
        prefs(context).getBoolean("background_location_update_enabled", true)

    fun getWidgetBearingMode(context: Context): WidgetBearingMode =
        WidgetBearingMode.fromPref(prefs(context).getString("widget_bearing_mode", null))

    fun isArrivalSoundEnabled(context: Context): Boolean =
        prefs(context).getBoolean("arrival_sound_enabled", false)

    fun isDistance114514SoundEnabled(context: Context): Boolean =
        prefs(context).getBoolean("distance_114514_sound_enabled", false)

    fun isDistanceIntervalSoundEnabled(context: Context): Boolean =
        prefs(context).getBoolean("distance_interval_sound_enabled", false)

    fun getDistanceIntervalSoundMeters(context: Context): Int =
        prefs(context).getInt("distance_interval_sound_meters", 1000)

    fun isSoundForegroundMonitorEnabled(context: Context): Boolean {
        return isArrivalSoundEnabled(context) ||
            isDistance114514SoundEnabled(context) ||
            isDistanceIntervalSoundEnabled(context)
    }

    fun isBackgroundLocationUpdateActive(context: Context): Boolean {
        return isBackgroundLocationUpdateEnabled(context) || isSoundForegroundMonitorEnabled(context)
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

object GeoUtils {
    private const val EARTH_RADIUS_M = 6_371_000.0

    fun distanceMeters(from: Destination, to: Destination): Float {
        val lat1 = Math.toRadians(from.lat)
        val lat2 = Math.toRadians(to.lat)
        val dLat = Math.toRadians(to.lat - from.lat)
        val dLng = Math.toRadians(to.lng - from.lng)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        return (EARTH_RADIUS_M * 2 * atan2(sqrt(a), sqrt(1 - a))).toFloat()
    }

    fun bearingDegrees(from: Destination, to: Destination): Float {
        val lat1 = Math.toRadians(from.lat)
        val lat2 = Math.toRadians(to.lat)
        val dLng = Math.toRadians(to.lng - from.lng)
        val y = sin(dLng) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        val degrees = Math.toDegrees(atan2(y, x)).toFloat()
        return normalizeTo360(degrees)
    }

    fun formatDistance(distanceMeters: Float): String {
        return if (distanceMeters >= 1000f) {
            String.format(Locale.US, "%.2f km", distanceMeters / 1000f)
        } else {
            "${distanceMeters.toInt()} m"
        }
    }

    fun cardinalFromBearing(bearing: Float): String {
        val dirs = arrayOf("N", "NE", "E", "SE", "S", "SW", "W", "NW")
        val idx = (((bearing + 22.5f) % 360f) / 45f).toInt()
        return dirs[idx]
    }

    fun normalizeTo360(value: Float): Float {
        if (!value.isFinite()) return 0f
        val mod = value % 360f
        return if (mod < 0f) mod + 360f else mod
    }
}

class DestinationWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        WidgetRenderer.render(context, appWidgetManager, appWidgetIds, R.layout.widget_small)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetRenderer.ACTION_REFRESH_WIDGETS) refreshAllWidgets(context)
    }

    companion object {
        fun refreshAllWidgets(context: Context) = WidgetRenderer.refreshAllWidgets(context)
    }
}

class DestinationWidgetProviderLarge : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        WidgetRenderer.render(context, appWidgetManager, appWidgetIds, R.layout.widget_large)
    }
}

object WidgetRenderer {
    const val ACTION_REFRESH_WIDGETS = "moe.n4tsu.beast.ACTION_REFRESH_WIDGETS"
    private const val ARROW_IMAGE_FORWARD_OFFSET_DEGREES = 45f

    fun render(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, layoutRes: Int) {
        val current = NativeStateStore.getLastKnownLocation(context)
        val target = NativeStateStore.getDestination(context)
        val heading = NativeStateStore.getLastKnownHeading(context)
        val widgetBearingMode = NativeStateStore.getWidgetBearingMode(context)
        val isArrived = NativeStateStore.isDestinationAnswered(context)
        val isSmallLayout = layoutRes == R.layout.widget_small
        val arrivalText = context.getString(if (isSmallLayout) R.string.widget_arrival_short else R.string.arrival_title)
        val normalDistanceText = if (current == null || !isValidDestination(current) || !isValidDestination(target)) {
            context.getString(R.string.widget_distance_placeholder)
        } else {
            formatWidgetDistance(GeoUtils.distanceMeters(current, target))
        }
        val absoluteBearing = if (current == null || !isValidDestination(current) || !isValidDestination(target)) {
            0f
        } else {
            GeoUtils.bearingDegrees(current, target)
        }
        val displayBearing = if (current == null) {
            0f
        } else if (widgetBearingMode == WidgetBearingMode.RELATIVE && heading != null) {
            GeoUtils.normalizeTo360(absoluteBearing - heading)
        } else {
            absoluteBearing
        }
        val titleText = if (current == null) {
            context.getString(R.string.widget_waiting_location)
        } else {
            context.getString(R.string.direction_label, GeoUtils.cardinalFromBearing(absoluteBearing))
        }
        val arrowRotation = GeoUtils.normalizeTo360(displayBearing - ARROW_IMAGE_FORWARD_OFFSET_DEGREES)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, layoutRes)
            if (isSmallLayout) {
                views.setViewVisibility(R.id.widgetTitle, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.widgetTitle, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widgetTitle, titleText)
            }
            if (isSmallLayout) {
                views.setTextViewText(R.id.widgetDistance, if (isArrived) arrivalText else normalDistanceText)
            } else if (isArrived) {
                views.setViewVisibility(R.id.widgetDistance, android.view.View.GONE)
                views.setViewVisibility(R.id.widgetArrivalDistance, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widgetArrivalDistance, arrivalText)
            } else {
                views.setViewVisibility(R.id.widgetDistance, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widgetArrivalDistance, android.view.View.GONE)
                views.setTextViewText(R.id.widgetDistance, normalDistanceText)
            }
            if (isArrived) {
                views.setViewVisibility(R.id.widgetArrow, android.view.View.GONE)
                views.setViewVisibility(R.id.widgetParty, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widgetParty, context.getString(R.string.widget_arrival_celebration))
            } else {
                views.setViewVisibility(R.id.widgetArrow, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widgetParty, android.view.View.GONE)
                views.setFloat(R.id.widgetArrow, "setRotation", arrowRotation)
            }
            views.setOnClickPendingIntent(
                R.id.widgetRoot,
                PendingIntent.getActivity(
                    context,
                    id,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    fun refreshAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        render(context, manager, manager.getAppWidgetIds(ComponentName(context, DestinationWidgetProvider::class.java)), R.layout.widget_small)
        render(context, manager, manager.getAppWidgetIds(ComponentName(context, DestinationWidgetProviderLarge::class.java)), R.layout.widget_large)
    }

    private fun formatWidgetDistance(distanceMeters: Float): String {
        return if (distanceMeters >= 1000f) {
            val km = distanceMeters / 1000f
            if (km >= 100f) String.format(Locale.US, "%.0f km", km) else String.format(Locale.US, "%.1f km", km)
        } else {
            "${distanceMeters.toInt()} m"
        }
    }

    private fun isValidDestination(destination: Destination): Boolean {
        return destination.lat.isFinite() && destination.lng.isFinite() &&
            destination.lat in -90.0..90.0 && destination.lng in -180.0..180.0
    }
}

object NotificationHelper {
    const val CHANNEL_ID = "destination_channel"
    private const val NOTIFICATION_ID = 1001
    private const val APPROACH_NOTIFICATION_ID = 1002
    private const val LIVE_UPDATE_MIN_SDK = 36

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, context.getString(R.string.notification_channel_name), NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    fun isLiveUpdateSupported(): Boolean = Build.VERSION.SDK_INT >= LIVE_UPDATE_MIN_SDK

    fun showDestinationReached(context: Context, message: String) {
        if (!NativeStateStore.isArrivalNotificationEnabled(context)) return
        if (!canPostNotifications(context)) return
        ensureChannel(context)
        val pendingIntent = PendingIntent.getActivity(
            context,
            20,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_arrow)
            .setContentTitle(context.getString(R.string.notification_title))
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    fun showApproachProgress(context: Context, remainingMeters: Float, progressPercent: Int) {
        if (!isLiveUpdateSupported() || !canPostNotifications(context)) return
        ensureChannel(context)
        val pendingIntent = PendingIntent.getActivity(
            context,
            21,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val clamped = progressPercent.coerceIn(0, 100)
        val body = context.getString(R.string.notification_live_body, GeoUtils.formatDistance(remainingMeters))
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_arrow)
            .setContentTitle(context.getString(R.string.notification_live_title))
            .setContentText(body)
            .setSubText(context.getString(R.string.notification_live_subtext))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setProgress(100, clamped, false)
            .setContentIntent(pendingIntent)
            .build()
        NotificationManagerCompat.from(context).notify(APPROACH_NOTIFICATION_ID, notification)
    }

    fun cancelApproachProgress(context: Context) {
        NotificationManagerCompat.from(context).cancel(APPROACH_NOTIFICATION_ID)
    }

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }
}

object GeofenceHelper {
    const val ACTION_GEOFENCE = "moe.n4tsu.beast.ACTION_GEOFENCE_EVENT"
    private const val GEOFENCE_ID = "destination_geofence"

    private fun geofencingClient(context: Context): GeofencingClient = LocationServices.getGeofencingClient(context)

    private fun geofencePendingIntent(context: Context): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            10,
            Intent(context, GeofenceBroadcastReceiver::class.java).apply { action = ACTION_GEOFENCE },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun canRegisterDestinationGeofence(context: Context): Boolean {
        val hasFine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFine) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val hasBackground = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!hasBackground) return false
        }
        return true
    }

    @SuppressLint("MissingPermission")
    fun registerDestinationGeofence(context: Context, destination: Destination) {
        if (!canRegisterDestinationGeofence(context)) return
        val geofence = Geofence.Builder()
            .setRequestId(GEOFENCE_ID)
            .setCircularRegion(destination.lat, destination.lng, 50f)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()
        runCatching { geofencingClient(context).addGeofences(request, geofencePendingIntent(context)) }
    }

    fun clearDestinationGeofence(context: Context) {
        geofencingClient(context).removeGeofences(geofencePendingIntent(context))
    }
}

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != GeofenceHelper.ACTION_GEOFENCE) return
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            if (NativeStateStore.isArrivalRearmRequired(context)) {
                NativeStateStore.setArrivalRearmRequired(context, false)
            }
            return
        }
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return
        if (NativeStateStore.isArrivalRearmRequired(context) || NativeStateStore.isDestinationAnswered(context)) return
        handleArrival(context, NativeStateStore.getDestination(context), playArrivalSound = true)
        val pending = goAsync()
        Thread {
            try {
                resolveArrivalNameAndNotify(context)
            } finally {
                pending.finish()
            }
        }.start()
    }
}

object BackgroundLocationUpdater {
    fun updateRegistration(context: Context) {
        val shouldRun = NativeStateStore.isBackgroundLocationUpdateActive(context) && hasRequiredPermission(context)
        if (shouldRun) ForegroundDistanceMonitorService.start(context) else ForegroundDistanceMonitorService.stop(context)
    }

    private fun hasRequiredPermission(context: Context): Boolean {
        val hasFine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFine) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
    }
}

class ForegroundDistanceMonitorService : Service() {
    private val fusedClient by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private var distance114514SoundPlayed = false
    private var lastIntervalBucket: Int? = null
    private var previousDistanceMeters: Float? = null
    private var lastWidgetUpdateTimeMs: Long = 0L

    private val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 4_000L)
        .setMinUpdateIntervalMillis(2_000L)
        .build()

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            if (NativeStateStore.isDebugDistanceOverrideEnabled(this@ForegroundDistanceMonitorService)) return
            val current = Destination(location.latitude, location.longitude)
            NativeStateStore.setLastKnownLocation(this@ForegroundDistanceMonitorService, current.lat, current.lng)
            if (location.hasBearing()) NativeStateStore.setLastKnownHeading(this@ForegroundDistanceMonitorService, location.bearing)
            val destination = NativeStateStore.getDestination(this@ForegroundDistanceMonitorService)
            val distanceMeters = GeoUtils.distanceMeters(current, destination)
            if (!NativeStateStore.isDestinationAnswered(this@ForegroundDistanceMonitorService)) {
                GeofenceHelper.registerDestinationGeofence(this@ForegroundDistanceMonitorService, destination)
            }
            if (NativeStateStore.isArrivalRearmRequired(this@ForegroundDistanceMonitorService) && distanceMeters > ARRIVAL_THRESHOLD_METERS) {
                NativeStateStore.setArrivalRearmRequired(this@ForegroundDistanceMonitorService, false)
            }
            if (!NativeStateStore.isArrivalRearmRequired(this@ForegroundDistanceMonitorService) &&
                !NativeStateStore.isDestinationAnswered(this@ForegroundDistanceMonitorService) &&
                distanceMeters <= ARRIVAL_THRESHOLD_METERS
            ) {
                handleArrival(this@ForegroundDistanceMonitorService, destination, playArrivalSound = true)
                Thread { resolveArrivalNameAndNotify(this@ForegroundDistanceMonitorService) }.start()
            }
            updateApproachLiveUpdate(distanceMeters)
            handleSoundTriggers(distanceMeters)
            val now = System.currentTimeMillis()
            if (now - lastWidgetUpdateTimeMs >= 10 * 60 * 1000L || distanceMeters <= NativeStateStore.getLiveUpdateStartDistanceMeters(this@ForegroundDistanceMonitorService)) {
                DestinationWidgetProvider.refreshAllWidgets(this@ForegroundDistanceMonitorService)
                lastWidgetUpdateTimeMs = now
            }
            previousDistanceMeters = distanceMeters
        }
    }

    override fun onCreate() {
        super.onCreate()
        createServiceChannelIfNeeded()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!NativeStateStore.isBackgroundLocationUpdateActive(this) || !hasLocationPermission()) {
            stopSelf()
            return START_NOT_STICKY
        }
        val foregroundStarted = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildServiceNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIFICATION_ID, buildServiceNotification())
            }
        }.isSuccess
        if (!foregroundStarted) {
            stopSelf()
            return START_NOT_STICKY
        }
        startLocationUpdates()
        return START_STICKY
    }

    override fun onDestroy() {
        fusedClient.removeLocationUpdates(locationCallback)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    @SuppressLint("MissingPermission")
    private fun startLocationUpdates() {
        if (!hasLocationPermission()) return
        runCatching { fusedClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper) }
            .onFailure { stopSelf() }
    }

    private fun handleSoundTriggers(distanceMeters: Float) {
        val previous = previousDistanceMeters
        val isInside114514Range =
            distanceMeters in DISTANCE_114514_LOWER_THRESHOLD_METERS..DISTANCE_114514_ENTER_THRESHOLD_METERS
        val crossed114514Range =
            previous != null &&
                previous > DISTANCE_114514_ENTER_THRESHOLD_METERS &&
                distanceMeters < DISTANCE_114514_LOWER_THRESHOLD_METERS
        if (NativeStateStore.isDistance114514SoundEnabled(this) &&
            !distance114514SoundPlayed &&
            (isInside114514Range || crossed114514Range)
        ) {
            distance114514SoundPlayed = true
            SoundEffectPlayer.play(this, R.raw.distance_114514km)
        } else if (distanceMeters > DISTANCE_114514_ENTER_THRESHOLD_METERS + 500f) {
            distance114514SoundPlayed = false
        }
        if (NativeStateStore.isDistanceIntervalSoundEnabled(this)) {
            val interval = NativeStateStore.getDistanceIntervalSoundMeters(this).coerceIn(100, 5000)
            val currentBucket = (distanceMeters / interval.toFloat()).toInt()
            val previousBucket = lastIntervalBucket
            lastIntervalBucket = currentBucket
            if (previousBucket != null && currentBucket < previousBucket) {
                SoundEffectPlayer.play(this, R.raw.distance_interval_kankaku)
            }
        } else {
            lastIntervalBucket = null
        }
    }

    private fun updateApproachLiveUpdate(distanceMeters: Float) {
        if (!NotificationHelper.isLiveUpdateSupported() ||
            !NativeStateStore.isLiveUpdateEnabled(this) ||
            NativeStateStore.isDestinationAnswered(this)
        ) {
            NotificationHelper.cancelApproachProgress(this)
            NativeStateStore.clearLiveUpdateAnchorDistanceMeters(this)
            return
        }
        val start = NativeStateStore.getLiveUpdateStartDistanceMeters(this).coerceIn(200, 5000).toFloat()
        if (distanceMeters > start || distanceMeters <= ARRIVAL_THRESHOLD_METERS) {
            NotificationHelper.cancelApproachProgress(this)
            NativeStateStore.clearLiveUpdateAnchorDistanceMeters(this)
            return
        }
        val anchor = NativeStateStore.getLiveUpdateAnchorDistanceMeters(this)?.takeIf { it > ARRIVAL_THRESHOLD_METERS }
            ?: distanceMeters.also { NativeStateStore.setLiveUpdateAnchorDistanceMeters(this, it) }
        val span = (anchor - ARRIVAL_THRESHOLD_METERS).coerceAtLeast(1f)
        val progress = (((anchor - distanceMeters) / span) * 100f).toInt().coerceIn(0, 100)
        NotificationHelper.showApproachProgress(this, distanceMeters, progress)
    }

    private fun hasLocationPermission(): Boolean {
        val hasFine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFine) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun buildServiceNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            41,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val body = when {
            NativeStateStore.isArrivalSoundEnabled(this) && NativeStateStore.isDistance114514SoundEnabled(this) && NativeStateStore.isDistanceIntervalSoundEnabled(this) -> getString(R.string.sound_monitor_notification_all)
            NativeStateStore.isArrivalSoundEnabled(this) && NativeStateStore.isDistance114514SoundEnabled(this) -> getString(R.string.sound_monitor_notification_both)
            NativeStateStore.isArrivalSoundEnabled(this) && NativeStateStore.isDistanceIntervalSoundEnabled(this) -> getString(R.string.sound_monitor_notification_arrival_and_interval)
            NativeStateStore.isDistance114514SoundEnabled(this) && NativeStateStore.isDistanceIntervalSoundEnabled(this) -> getString(R.string.sound_monitor_notification_114514_and_interval)
            NativeStateStore.isArrivalSoundEnabled(this) -> getString(R.string.sound_monitor_notification_arrival_only)
            NativeStateStore.isDistance114514SoundEnabled(this) -> getString(R.string.sound_monitor_notification_114514_only)
            NativeStateStore.isDistanceIntervalSoundEnabled(this) -> getString(R.string.sound_monitor_notification_interval_only)
            else -> getString(R.string.sound_monitor_notification_background_only)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_arrow)
            .setContentTitle(getString(R.string.sound_monitor_notification_title))
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createServiceChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, getString(R.string.sound_monitor_channel_name), NotificationManager.IMPORTANCE_LOW)
        )
    }

    companion object {
        private const val CHANNEL_ID = "sound_monitor_channel"
        private const val NOTIFICATION_ID = 1514
        private const val ARRIVAL_THRESHOLD_METERS = 50f
        private const val DISTANCE_114514_METERS = 114_514f
        private const val DISTANCE_114514_TOLERANCE_METERS = 80f
        private const val DISTANCE_114514_ENTER_THRESHOLD_METERS =
            DISTANCE_114514_METERS + DISTANCE_114514_TOLERANCE_METERS
        private const val DISTANCE_114514_LOWER_THRESHOLD_METERS =
            DISTANCE_114514_METERS - DISTANCE_114514_TOLERANCE_METERS

        fun start(context: Context) {
            val intent = Intent(context, ForegroundDistanceMonitorService::class.java)
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ContextCompat.startForegroundService(context, intent)
                else context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ForegroundDistanceMonitorService::class.java))
        }
    }
}

object SoundEffectPlayer {
    fun play(context: Context, rawResId: Int) {
        val priority = when (rawResId) {
            R.raw.distance_114514km -> 3
            R.raw.arrival_0km -> 2
            R.raw.distance_interval_kankaku -> 1
            else -> 0
        }
        SoundPlaybackService.start(context, rawResId, priority)
    }
}

class SoundPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var currentPriority: Int = 0

    override fun onCreate() {
        super.onCreate()
        createChannelIfNeeded()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val rawResId = intent?.getIntExtra(EXTRA_RAW_RES_ID, 0) ?: 0
        val priority = intent?.getIntExtra(EXTRA_PRIORITY, 0) ?: 0
        if (rawResId == 0) {
            stopSelf()
            return START_NOT_STICKY
        }
        runCatching { startForeground(NOTIFICATION_ID, buildNotification()) }.onFailure {
            stopSelf()
            return START_NOT_STICKY
        }
        if (player != null && priority <= currentPriority) return START_NOT_STICKY
        playRaw(rawResId, priority)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopPlayer()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun playRaw(rawResId: Int, priority: Int) {
        stopPlayer()
        val attributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .build()
        val created = MediaPlayer.create(this, rawResId, attributes, 0) ?: run {
            stopSelf()
            return
        }
        currentPriority = priority
        player = created.apply {
            setOnCompletionListener {
                stopPlayer()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            start()
        }
    }

    private fun stopPlayer() {
        player?.runCatching { if (isPlaying) stop() }
        player?.release()
        player = null
        currentPriority = 0
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_arrow)
            .setContentTitle(getString(R.string.sound_playback_notification_title))
            .setContentText(getString(R.string.sound_playback_notification_body))
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, getString(R.string.sound_playback_channel_name), NotificationManager.IMPORTANCE_LOW)
        )
    }

    companion object {
        private const val CHANNEL_ID = "sound_playback_channel"
        private const val NOTIFICATION_ID = 1515
        private const val EXTRA_RAW_RES_ID = "extra_raw_res_id"
        private const val EXTRA_PRIORITY = "extra_priority"

        fun start(context: Context, rawResId: Int, priority: Int) {
            val intent = Intent(context, SoundPlaybackService::class.java).apply {
                putExtra(EXTRA_RAW_RES_ID, rawResId)
                putExtra(EXTRA_PRIORITY, priority)
            }
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ContextCompat.startForegroundService(context, intent)
                else context.startService(intent)
            }
        }
    }
}

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            BackgroundLocationUpdater.updateRegistration(context)
            DestinationWidgetProvider.refreshAllWidgets(context)
        }
    }
}

object ReverseGeocoder {
    fun resolve(context: Context, destination: Destination): String {
        return try {
            @Suppress("DEPRECATION")
            Geocoder(context, Locale.JAPAN)
                .getFromLocation(destination.lat, destination.lng, 1)
                ?.firstOrNull()
                ?.getAddressLine(0)
                ?: fallback(destination)
        } catch (_: Exception) {
            fallback(destination)
        }
    }

    private fun fallback(destination: Destination): String {
        return "${destination.lat}, ${destination.lng}"
    }
}

private fun handleArrival(context: Context, destination: Destination, playArrivalSound: Boolean) {
    if (playArrivalSound && NativeStateStore.isArrivalSoundEnabled(context)) {
        SoundEffectPlayer.play(context, R.raw.arrival_0km)
    }
    NativeStateStore.setDestinationAnswered(context, true)
    NativeStateStore.setArrivalDestinationName(context, "${destination.lat}, ${destination.lng}")
    NotificationHelper.cancelApproachProgress(context)
    NotificationHelper.showDestinationReached(
        context,
        context.getString(R.string.notification_body, "${destination.lat}, ${destination.lng}")
    )
    GeofenceHelper.clearDestinationGeofence(context)
    DestinationWidgetProvider.refreshAllWidgets(context)
}

private fun resolveArrivalNameAndNotify(context: Context) {
    val destination = NativeStateStore.getDestination(context)
    val resolved = ReverseGeocoder.resolve(context, destination)
    if (!NativeStateStore.isDestinationAnswered(context)) return
    NativeStateStore.setArrivalDestinationName(context, resolved)
    NotificationHelper.showDestinationReached(context, context.getString(R.string.notification_body, resolved))
    DestinationWidgetProvider.refreshAllWidgets(context)
}
