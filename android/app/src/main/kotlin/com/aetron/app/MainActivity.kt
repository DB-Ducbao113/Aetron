package com.aetron.app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
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
import android.os.SystemClock
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    private val gnssStatusChannel = "com.aetron.app/gnss_status"
    private val lightSensorChannel = "com.aetron.app/light_sensor"
    private val sensorCheckChannel = "com.aetron.app/sensors_check"

    private var locationManager: LocationManager? = null
    private var sensorManager: SensorManager? = null
    private var lightSensor: Sensor? = null

    private var gnssStatusCallback: GnssStatus.Callback? = null
    private var lightEventListener: SensorEventListener? = null
    private var stepSensorHandler: Any? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Bluetooth Low Energy Scanning State (Yoo 2025 Transition Framework)
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private var isBleScanning = false
    private val bleBeacons = ConcurrentHashMap<String, Pair<Double, Long>>() // address -> (rssiDbm, timestampMs)
    private val bleScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.let {
                val address = it.device?.address ?: return
                val rssi = it.rssi.toDouble()
                bleBeacons[address] = Pair(rssi, System.currentTimeMillis())
            }
        }
        override fun onBatchScanResults(results: MutableList<ScanResult>?) {
            results?.forEach {
                val address = it.device?.address ?: return@forEach
                bleBeacons[address] = Pair(it.rssi.toDouble(), System.currentTimeMillis())
            }
        }
        override fun onScanFailed(errorCode: Int) {
            // Non-fatal scan failure
        }
    }

    private fun ensureBleScanning() {
        if (isBleScanning) return
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: return
        if (!adapter.isEnabled) return

        val scanPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
        if (!scanPerm) return

        try {
            bluetoothLeScanner = adapter.bluetoothLeScanner
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            bluetoothLeScanner?.startScan(null, settings, bleScanCallback)
            isBleScanning = true
        } catch (_: Exception) {
            isBleScanning = false
        }
    }

    private fun stopBleScanning() {
        if (!isBleScanning) return
        try {
            bluetoothLeScanner?.stopScan(bleScanCallback)
        } catch (_: Exception) {}
        isBleScanning = false
        bluetoothLeScanner = null
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        lightSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)

        // Step Sensor Platform Integration (preserves step counter capability safely)
        try {
            val clazz = Class.forName("com.aetron.app.StepSensorHandler")
            val ctor = clazz.getConstructor(Context::class.java, io.flutter.plugin.common.BinaryMessenger::class.java)
            val handler = ctor.newInstance(this, flutterEngine.dartExecutor.binaryMessenger)
            clazz.getMethod("register").invoke(handler)
            stepSensorHandler = handler
            android.util.Log.i("MainActivity", "StepSensorHandler successfully initialized and registered.")
        } catch (e: ClassNotFoundException) {
            android.util.Log.i("MainActivity", "StepSensorHandler not found on classpath (clean checkout mode).")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "StepSensorHandler initialization/registration failed", e)
        }

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

                        // Opportunistically request scan start (safe against throttling on Android 9+)
                        try {
                            wifiManager.startScan()
                        } catch (_: Exception) {}

                        try {
                            val scanResults = wifiManager.scanResults ?: emptyList()
                            val nowElapsedMicros = SystemClock.elapsedRealtime() * 1000L
                            val maxAgeMicros = 30_000_000L // 30 seconds

                            val freshResults = scanResults.filter { sr ->
                                if (sr.timestamp > 0) {
                                    (nowElapsedMicros - sr.timestamp) < maxAgeMicros
                                } else {
                                    true
                                }
                            }

                            if (freshResults.isNotEmpty()) {
                                val fingerprint = mutableMapOf<String, Double>()
                                var sumRssi = 0.0
                                for (sr in freshResults) {
                                    fingerprint[sr.BSSID] = sr.level.toDouble()
                                    sumRssi += sr.level
                                }
                                val meanRssi = sumRssi / freshResults.size
                                result.success(
                                    mapOf(
                                        "hasScan" to true,
                                        "count" to freshResults.size,
                                        "meanRssiDbm" to meanRssi,
                                        "fingerprint" to fingerprint,
                                        "timestamp" to System.currentTimeMillis()
                                    )
                                )
                            } else {
                                result.success(
                                    mapOf(
                                        "hasScan" to false,
                                        "count" to 0,
                                        "reason" to "NO_FRESH_WIFI_SCANS",
                                        "timestamp" to System.currentTimeMillis()
                                    )
                                )
                            }
                        } catch (e: Exception) {
                            result.success(mapOf("hasScan" to false, "reason" to (e.message ?: "UNKNOWN_ERROR")))
                        }
                    }
                    "getBleScan" -> {
                        val fineLocGranted = ContextCompat.checkSelfPermission(
                            context,
                            android.Manifest.permission.ACCESS_FINE_LOCATION
                        ) == PackageManager.PERMISSION_GRANTED

                        val scanPermGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            ContextCompat.checkSelfPermission(
                                context,
                                android.Manifest.permission.BLUETOOTH_SCAN
                            ) == PackageManager.PERMISSION_GRANTED
                        } else {
                            fineLocGranted
                        }

                        if (!scanPermGranted) {
                            result.success(
                                mapOf(
                                    "hasScan" to false,
                                    "count" to 0,
                                    "reason" to "PERMISSION_DENIED",
                                    "timestamp" to System.currentTimeMillis()
                                )
                            )
                            return@setMethodCallHandler
                        }

                        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val bluetoothAdapter = bluetoothManager?.adapter
                        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
                            result.success(
                                mapOf(
                                    "hasScan" to false,
                                    "count" to 0,
                                    "reason" to "BLUETOOTH_DISABLED",
                                    "timestamp" to System.currentTimeMillis()
                                )
                            )
                            return@setMethodCallHandler
                        }

                        // Ensure background BLE scanner is listening
                        ensureBleScanning()

                        val now = System.currentTimeMillis()
                        val maxAgeMs = 15_000L
                        // Evict stale records older than 15s to keep map lean and fresh
                        bleBeacons.entries.removeIf { now - it.value.second >= maxAgeMs }
                        val freshBeacons = bleBeacons.filter { now - it.value.second < maxAgeMs }

                        if (freshBeacons.isNotEmpty()) {
                            val fingerprint = freshBeacons.mapValues { it.value.first }
                            var sumRssi = 0.0
                            for (v in fingerprint.values) {
                                sumRssi += v
                            }
                            val meanRssi = sumRssi / fingerprint.size
                            result.success(
                                mapOf(
                                    "hasScan" to true,
                                    "count" to fingerprint.size,
                                    "meanRssiDbm" to meanRssi,
                                    "fingerprint" to fingerprint,
                                    "timestamp" to now
                                )
                            )
                        } else {
                            result.success(
                                mapOf(
                                    "hasScan" to false,
                                    "count" to 0,
                                    "reason" to "NO_BEACONS_DETECTED",
                                    "timestamp" to now
                                )
                            )
                        }
                    }
                    "startBleScan" -> {
                        val fineLocGranted = ContextCompat.checkSelfPermission(
                            context,
                            android.Manifest.permission.ACCESS_FINE_LOCATION
                        ) == PackageManager.PERMISSION_GRANTED

                        val scanPermGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            ContextCompat.checkSelfPermission(
                                context,
                                android.Manifest.permission.BLUETOOTH_SCAN
                            ) == PackageManager.PERMISSION_GRANTED
                        } else {
                            fineLocGranted
                        }

                        if (!scanPermGranted) {
                            result.success(mapOf("started" to false, "reason" to "PERMISSION_DENIED"))
                            return@setMethodCallHandler
                        }

                        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val bluetoothAdapter = bluetoothManager?.adapter
                        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
                            result.success(mapOf("started" to false, "reason" to "BLUETOOTH_DISABLED"))
                            return@setMethodCallHandler
                        }

                        ensureBleScanning()
                        result.success(mapOf("started" to isBleScanning, "reason" to if (isBleScanning) "OK" else "SCANNER_FAILED"))
                    }
                    "stopBleScan" -> {
                        stopBleScanning()
                        bleBeacons.clear()
                        result.success(true)
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
        stopBleScanning()
        bleBeacons.clear()

        try {
            stepSensorHandler?.let {
                it.javaClass.getMethod("unregister").invoke(it)
                android.util.Log.i("MainActivity", "StepSensorHandler successfully unregistered.")
            }
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Failed to unregister StepSensorHandler: ${e.message}")
        }
        stepSensorHandler = null

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
