package com.tuinstituto.fitness_tracker

import android.os.Bundle
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

// Importaciones adicionales
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt
import io.flutter.plugin.common.EventChannel

// Importaciones GPS
import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import androidx.core.app.ActivityCompat

// NUEVO: Importaciones para notificaciones
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * MainActivity con soporte completo de Platform Channels
 */
class MainActivity: FlutterFragmentActivity() {

    // Canales existentes
    private val BIOMETRIC_CHANNEL = "com.tuinstituto.fitness/biometric"
    private val ACCELEROMETER_CHANNEL = "com.tuinstituto.fitness/accelerometer"
    private val GPS_CHANNEL = "com.tuinstituto.fitness/gps"
    
    // NUEVO: Canal de notificaciones
    private val NOTIFICATIONS_CHANNEL = "com.tuinstituto.fitness/notifications"
    
    // NUEVO: IDs para notificaciones
    private val CHANNEL_ID = "fitness_notifications"
    private val STEP_GOAL_NOTIFICATION_ID = 1
    private val FALL_ALERT_NOTIFICATION_ID = 2

    // Variables existentes para biometría
    private lateinit var executor: Executor
    private lateinit var biometricPrompt: BiometricPrompt
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        executor = ContextCompat.getMainExecutor(this)

        // NUEVO: Crear canal de notificaciones
        createNotificationChannel()

        // Configurar canales existentes
        setupBiometricChannel(flutterEngine)
        setupAccelerometerChannel(flutterEngine)
        setupGpsChannel(flutterEngine)
        
        // NUEVO: Configurar canal de notificaciones
        setupNotificationChannel(flutterEngine)
    }

    // ═══════════════════════════════════════════════════════════
    // NUEVO: CONFIGURACIÓN DE NOTIFICACIONES
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Crear canal de notificaciones (requerido en Android 8.0+)
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Fitness Notifications"
            val descriptionText = "Notificaciones de logros y alertas"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
            }

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Configurar Platform Channel para notificaciones
     */
    private fun setupNotificationChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showStepGoalNotification" -> {
                    val steps = call.argument<Int>("steps") ?: 0
                    showStepGoalNotification(steps)
                    result.success(null)
                }
                
                "showFallAlert" -> {
                    showFallAlert()
                    result.success(null)
                }
                
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Mostrar notificación de meta de pasos alcanzada
     */
    private fun showStepGoalNotification(steps: Int) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("🎉 ¡Meta alcanzada!")
            .setContentText("Has caminado $steps pasos. ¡Sigue así!")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .build()

        with(NotificationManagerCompat.from(this)) {
            if (ActivityCompat.checkSelfPermission(
                    this@MainActivity,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                notify(STEP_GOAL_NOTIFICATION_ID, notification)
            }
        }
    }

    /**
     * Mostrar alerta de caída detectada
     */
    private fun showFallAlert() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ Caída detectada")
            .setContentText("Se ha detectado una posible caída. ¿Estás bien?")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 250, 500))
            .build()

        with(NotificationManagerCompat.from(this)) {
            if (ActivityCompat.checkSelfPermission(
                    this@MainActivity,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                notify(FALL_ALERT_NOTIFICATION_ID, notification)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // CANALES EXISTENTES (sin cambios)
    // ═══════════════════════════════════════════════════════════

    private fun setupBiometricChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BIOMETRIC_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkBiometricSupport" -> {
                    val canAuth = checkBiometricSupport()
                    result.success(canAuth)
                }
                "authenticate" -> {
                    pendingResult = result
                    showBiometricPrompt()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkBiometricSupport(): Boolean {
        val biometricManager = BiometricManager.from(this)
        return when (biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        )) {
            BiometricManager.BIOMETRIC_SUCCESS -> true
            else -> false
        }
    }

    private fun showBiometricPrompt() {
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Autenticación Biométrica")
            .setSubtitle("Usa tu huella dactilar")
            .setDescription("Coloca tu dedo en el sensor")
            .setNegativeButtonText("Cancelar")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult
                ) {
                    super.onAuthenticationSucceeded(result)
                    pendingResult?.success(true)
                    pendingResult = null
                }

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence
                ) {
                    super.onAuthenticationError(errorCode, errString)
                    pendingResult?.success(false)
                    pendingResult = null
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                }
            }
        )

        biometricPrompt.authenticate(promptInfo)
    }

    private fun setupAccelerometerChannel(flutterEngine: FlutterEngine) {
        val sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        var stepCount = 0
        var lastMagnitude = 0.0
        var sensorEventListener: SensorEventListener? = null

        // ═══════════════════════════════════════════════════════
        // AJUSTE DE SENSIBILIDAD DEL ACELERÓMETRO
        // ═══════════════════════════════════════════════════════
        val magnitudeHistory = mutableListOf<Double>()
        val historySize = 15  // Aumentado de 10 a 15 (más suavizado)
        var sampleCount = 0
        var lastActivityType = "stationary"
        var activityConfidence = 0

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCELEROMETER_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sensorEventListener = object : SensorEventListener {

                    override fun onSensorChanged(event: SensorEvent?) {
                        event?.let {
                            val x = it.values[0]
                            val y = it.values[1]
                            val z = it.values[2]
                            val magnitude = sqrt((x * x + y * y + z * z).toDouble())

                            magnitudeHistory.add(magnitude)
                            if (magnitudeHistory.size > historySize) {
                                magnitudeHistory.removeAt(0)
                            }
                            val avgMagnitude = magnitudeHistory.average()

                            // Umbral más alto para detectar pasos (menos sensible)
                            if (magnitude > 14 && lastMagnitude <= 14) {  // Cambio: 12 → 13
                                stepCount++
                            }
                            lastMagnitude = magnitude

                            val newActivityType = when {
                                avgMagnitude < 10.8 -> "stationary"  // Cambio: 10.5 → 10.8
                                avgMagnitude < 14.0 -> "walking"     // Cambio: 13.5 → 14.0
                                else -> "running"
                            }

                            if (newActivityType == lastActivityType) {
                                activityConfidence++
                            } else {
                                activityConfidence = 0
                            }

                            val finalActivityType = if (activityConfidence >= 5) {  // Cambio: 3 → 5
                                newActivityType
                            } else {
                                lastActivityType
                            }
                            lastActivityType = newActivityType

                            sampleCount++
                            // Enviar cada 5 muestras (antes: 3)
                            if (sampleCount >= 5) {
                                sampleCount = 0

                                val data = mapOf(
                                    "stepCount" to stepCount,
                                    "activityType" to finalActivityType,
                                    "magnitude" to avgMagnitude
                                )

                                events?.success(data)
                            }
                        }
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }

                // ═══════════════════════════════════════════════════════
                // AJUSTE: Frecuencia de muestreo más lenta
                // ═══════════════════════════════════════════════════════
                sensorManager.registerListener(
                    sensorEventListener,
                    accelerometer,
                    SensorManager.SENSOR_DELAY_UI  // Cambio: SENSOR_DELAY_GAME → SENSOR_DELAY_UI
                )
            }

            override fun onCancel(arguments: Any?) {
                sensorEventListener?.let {
                    sensorManager.unregisterListener(it)
                }
                sensorEventListener = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "$ACCELEROMETER_CHANNEL/control"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    stepCount = 0
                    result.success(null)
                }
                "stop" -> {
                    result.success(null)
                }
                "reset" -> {
                    stepCount = 0
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupGpsChannel(flutterEngine: FlutterEngine) {
        val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        var locationListener: LocationListener? = null

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GPS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGpsEnabled" -> {
                    val isEnabled = locationManager.isProviderEnabled(
                        LocationManager.GPS_PROVIDER
                    )
                    result.success(isEnabled)
                }

                "requestPermissions" -> {
                    if (hasLocationPermission()) {
                        result.success(true)
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            ),
                            LOCATION_PERMISSION_REQUEST_CODE
                        )
                        result.success(hasLocationPermission())
                    }
                }

                "getCurrentLocation" -> {
                    if (!hasLocationPermission()) {
                        result.error("PERMISSION_DENIED", "Sin permisos", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val location = locationManager.getLastKnownLocation(
                            LocationManager.GPS_PROVIDER
                        ) ?: locationManager.getLastKnownLocation(
                            LocationManager.NETWORK_PROVIDER
                        )

                        if (location != null) {
                            result.success(locationToMap(location))
                        } else {
                            result.error("NO_LOCATION", "No disponible", null)
                        }
                    } catch (e: SecurityException) {
                        result.error("SECURITY_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "$GPS_CHANNEL/stream"
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (!hasLocationPermission()) {
                    events?.error("PERMISSION_DENIED", "Sin permisos", null)
                    return
                }

                locationListener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        events?.success(locationToMap(location))
                    }

                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }

                try {
                    locationManager.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        1000L,
                        0f,
                        locationListener!!
                    )
                } catch (e: SecurityException) {
                    events?.error("SECURITY_ERROR", e.message, null)
                }
            }

            override fun onCancel(arguments: Any?) {
                locationListener?.let {
                    locationManager.removeUpdates(it)
                }
                locationListener = null
            }
        })
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun locationToMap(location: Location): Map<String, Any> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "altitude" to location.altitude,
            "speed" to location.speed.toDouble(),
            "accuracy" to location.accuracy.toDouble(),
            "timestamp" to location.time
        )
    }
}