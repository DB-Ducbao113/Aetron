package com.aetron.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles Android Hardware Step Counter (Sensor.TYPE_STEP_COUNTER)
 * and exposes method/event channels to Flutter.
 */
class StepSensorHandler(
    private val context: Context,
    private val messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, "com.aetron.app/step_sensor")
    private val eventChannel = EventChannel(messenger, "com.aetron.app/step_sensor_events")

    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    private val stepDetectorSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var sensorEventListener: SensorEventListener? = null
    private var isTracking = false

    fun register() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun unregister() {
        stopSensor()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkStatus" -> {
                val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.ACTIVITY_RECOGNITION
                    ) == PackageManager.PERMISSION_GRANTED
                } else {
                    true
                }

                val isAvailable = stepCounterSensor != null
                result.success(
                    mapOf(
                        "isAvailable" to isAvailable,
                        "hasPermission" to hasPermission,
                        "isCadenceAvailable" to false,
                        "isHistoricalQueryAvailable" to false,
                        "message" to if (!isAvailable) "Hardware step counter not available" else null
                    )
                )
            }
            "startTracking" -> {
                startSensor()
                result.success(true)
            }
            "stopTracking" -> {
                stopSensor()
                result.success(true)
            }
            "queryHistoricalSteps" -> {
                // Not supported natively on standard Android without Health Connect
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        startSensor()
    }

    override fun onCancel(arguments: Any?) {
        stopSensor()
        this.eventSink = null
    }

    private fun startSensor() {
        if (isTracking || sensorManager == null || stepCounterSensor == null) return

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null || event.values.isEmpty()) return

                val rawSteps = event.values[0].toInt()

                // Convert sensor event timestamp (nanoseconds since boot) to epoch milliseconds
                val bootTimeMs = System.currentTimeMillis() - SystemClock.elapsedRealtime()
                val eventTimeMs = bootTimeMs + (event.timestamp / 1_000_000L)

                val payload = mapOf(
                    "rawSteps" to rawSteps,
                    "timestampMs" to eventTimeMs,
                    "source" to "androidStepCounter"
                )

                mainHandler.post {
                    eventSink?.success(payload)
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorEventListener = listener
        // Use SENSOR_DELAY_FASTEST for minimal latency during workout tracking
        sensorManager.registerListener(
            listener,
            stepCounterSensor,
            SensorManager.SENSOR_DELAY_FASTEST
        )
        isTracking = true
    }

    private fun stopSensor() {
        sensorEventListener?.let {
            sensorManager?.unregisterListener(it)
        }
        sensorEventListener = null
        isTracking = false
    }
}

