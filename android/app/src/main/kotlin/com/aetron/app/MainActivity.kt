package com.aetron.app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.GnssStatus
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val gnssStatusChannel = "com.aetron.app/gnss_status"
    private val lightSensorChannel = "com.aetron.app/light_sensor"
    private val sensorCheckChannel = "com.aetron.app/sensors_check"

    private var locationManager: LocationManager? = null
    private var sensorManager: SensorManager? = null
    private var lightSensor: Sensor? = null

    private var gnssStatusCallback: GnssStatus.Callback? = null
    private var lightEventListener: SensorEventListener? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        lightSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)

        // 1. MethodChannel to probe hardware capabilities
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sensorCheckChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "checkSensorAvailability" -> {
                        val hasLight = lightSensor != null
                        val hasGnss = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && locationManager != null
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val bluetoothAdapter = bluetoothManager?.adapter
                        result.success(
                            mapOf(
                                "hasLightSensor" to hasLight,
                                "hasGnssStatus" to hasGnss,
                                "hasWifi" to (wifiManager != null),
                                "hasBluetooth" to (bluetoothAdapter != null)
                            )
                        )
                    }
                    "getWifiScan" -> {
                        val fineLocGranted = ContextCompat.checkSelfPermission(
                            context,
                            android.Manifest.permission.ACCESS_FINE_LOCATION
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!fineLocGranted) {
                            result.success(mapOf("hasScan" to false, "reason" to "PERMISSION_DENIED"))
                            return@setMethodCallHandler
                        }

                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        if (wifiManager == null) {
                            result.success(mapOf("hasScan" to false, "reason" to "WIFI_UNAVAILABLE"))
                            return@setMethodCallHandler
                        }

                        try {
                            val scanResults = wifiManager.scanResults ?: emptyList()
                            val fingerprint = mutableMapOf<String, Double>()
                            var sumRssi = 0.0
                            for (sr in scanResults) {
                                fingerprint[sr.BSSID] = sr.level.toDouble()
                                sumRssi += sr.level
                            }
                            val meanRssi = if (scanResults.isNotEmpty()) sumRssi / scanResults.size else null
                            result.success(
                                mapOf(
                                    "hasScan" to scanResults.isNotEmpty(),
                                    "count" to scanResults.size,
                                    "meanRssiDbm" to meanRssi,
                                    "fingerprint" to fingerprint,
                                    "timestamp" to System.currentTimeMillis()
                                )
                            )
                        } catch (e: Exception) {
                            result.success(mapOf("hasScan" to false, "reason" to (e.message ?: "UNKNOWN_ERROR")))
                        }
                    }
                    "getBleScan" -> {
                        val fineLocGranted = ContextCompat.checkSelfPermission(
                            context,
                            android.Manifest.permission.ACCESS_FINE_LOCATION
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!fineLocGranted) {
                            result.success(mapOf("hasScan" to false, "reason" to "PERMISSION_DENIED"))
                            return@setMethodCallHandler
                        }

                        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val bluetoothAdapter = bluetoothManager?.adapter
                        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
                            result.success(mapOf("hasScan" to false, "reason" to "BLUETOOTH_DISABLED"))
                            return@setMethodCallHandler
                        }

                        // Opportunistic BLE query returning device capability
                        result.success(
                            mapOf(
                                "hasScan" to false,
                                "count" to 0,
                                "reason" to "IDLE",
                                "timestamp" to System.currentTimeMillis()
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. EventChannel for GNSS Satellite Status & C/N0
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, gnssStatusChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || locationManager == null) {
                        events?.error("UNAVAILABLE", "GNSS status callback requires Android N or higher", null)
                        return
                    }

                    val fineLocGranted = ContextCompat.checkSelfPermission(
                        context,
                        android.Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED

                    if (!fineLocGranted) {
                        events?.error("PERMISSION_DENIED", "ACCESS_FINE_LOCATION is required for GNSS status", null)
                        return
                    }

                    try {
                        val callback = object : GnssStatus.Callback() {
                            override fun onSatelliteStatusChanged(status: GnssStatus) {
                                val satCount = status.satelliteCount
                                var usedInFixCount = 0
                                var cn0Sum = 0.0
                                var maxCn0 = 0.0
                                val cn0List = mutableListOf<Double>()

                                for (i in 0 until satCount) {
                                    val cn0 = status.getCn0DbHz(i).toDouble()
                                    cn0List.add(cn0)
                                    cn0Sum += cn0
                                    if (cn0 > maxCn0) maxCn0 = cn0
                                    if (status.usedInFix(i)) {
                                        usedInFixCount++
                                    }
                                }

                                val meanCn0 = if (satCount > 0) cn0Sum / satCount else 0.0
                                cn0List.sortDescending()
                                val top4 = cn0List.take(4)
                                val top4MeanCn0 = if (top4.isNotEmpty()) top4.sum() / top4.size else 0.0

                                val payload = mapOf(
                                    "satelliteCount" to satCount,
                                    "usedInFixCount" to usedInFixCount,
                                    "meanCn0DbHz" to meanCn0,
                                    "maxCn0DbHz" to maxCn0,
                                    "top4Cn0DbHz" to top4MeanCn0,
                                    "timestamp" to System.currentTimeMillis()
                                )

                                mainHandler.post {
                                    events?.success(payload)
                                }
                            }
                        }

                        gnssStatusCallback = callback
                        locationManager?.registerGnssStatusCallback(callback, mainHandler)
                    } catch (e: SecurityException) {
                        events?.error("SECURITY_EXCEPTION", e.message, null)
                    } catch (e: Exception) {
                        events?.error("GNSS_REGISTRATION_ERROR", e.message, null)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    gnssStatusCallback?.let {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            locationManager?.unregisterGnssStatusCallback(it)
                        }
                    }
                    gnssStatusCallback = null
                }
            })

        // 3. EventChannel for Ambient Light Sensor (Lux)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, lightSensorChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (lightSensor == null || sensorManager == null) {
                        events?.error("UNAVAILABLE", "Ambient light sensor not available on this device", null)
                        return
                    }

                    val listener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent?) {
                            event?.let {
                                if (it.sensor.type == Sensor.TYPE_LIGHT && it.values.isNotEmpty()) {
                                    val lux = it.values[0].toDouble()
                                    val payload = mapOf(
                                        "lux" to lux,
                                        "timestamp" to System.currentTimeMillis()
                                    )
                                    mainHandler.post {
                                        events?.success(payload)
                                    }
                                }
                            }
                        }

                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                    }

                    lightEventListener = listener
                    sensorManager?.registerListener(
                        listener,
                        lightSensor,
                        SensorManager.SENSOR_DELAY_NORMAL
                    )
                }

                override fun onCancel(arguments: Any?) {
                    lightEventListener?.let {
                        sensorManager?.unregisterListener(it)
                    }
                    lightEventListener = null
                }
            })
    }

    override fun onDestroy() {
        gnssStatusCallback?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                locationManager?.unregisterGnssStatusCallback(it)
            }
        }
        gnssStatusCallback = null

        lightEventListener?.let {
            sensorManager?.unregisterListener(it)
        }
        lightEventListener = null

        super.onDestroy()
    }
}
