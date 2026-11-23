import CoreMotion
import Flutter
import UIKit

public class AetronStepSensorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let pedometer = CMPedometer()
    private var isTracking = false
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AetronStepSensorPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "com.aetron.app/step_sensor",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "com.aetron.app/step_sensor_events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkStatus":
            let isAvailable = CMPedometer.isStepCountingAvailable()
            var hasPermission = false
            if #available(iOS 11.0, *) {
                hasPermission = CMPedometer.authorizationStatus() == .authorized
            } else {
                hasPermission = isAvailable
            }

            var isCadenceAvailable = false
            if #available(iOS 9.0, *) {
                isCadenceAvailable = CMPedometer.isCadenceAvailable()
            }

            result([
                "isAvailable": isAvailable,
                "hasPermission": hasPermission,
                "isCadenceAvailable": isCadenceAvailable,
                "isHistoricalQueryAvailable": isAvailable,
                "message": isAvailable ? nil : "CMPedometer step counting is not available"
            ])

        case "startTracking":
            startPedometer()
            result(true)

        case "stopTracking":
            stopPedometer()
            result(true)

        case "queryHistoricalSteps":
            guard let args = call.arguments as? [String: Any],
                  let startMs = args["startMs"] as? Double,
                  let endMs = args["endMs"] as? Double else {
                result(nil)
                return
            }

            let startDate = Date(timeIntervalSince1970: startMs / 1000.0)
            let endDate = Date(timeIntervalSince1970: endMs / 1000.0)

            guard CMPedometer.isStepCountingAvailable() else {
                result(nil)
                return
            }

            pedometer.queryPedometerData(from: startDate, to: endDate) { data, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        result(nil)
                    }
                    return
                }

                let response: [String: Any] = [
                    "steps": data.numberOfSteps.intValue,
                    "startMs": Int64(data.startDate.timeIntervalSince1970 * 1000),
                    "endMs": Int64(data.endDate.timeIntervalSince1970 * 1000)
                ]
                DispatchQueue.main.async {
                    result(response)
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        startPedometer()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopPedometer()
        self.eventSink = nil
        return nil
    }

    private func startPedometer() {
        guard !isTracking else { return }
        guard CMPedometer.isStepCountingAvailable() else {
            eventSink?(FlutterError(code: "UNAVAILABLE", message: "Step counting not available", details: nil))
            return
        }

        let systemUptime = ProcessInfo.processInfo.systemUptime
        let timeNow = Date().timeIntervalSince1970
        let dateOfLastReboot = Date(timeIntervalSince1970: timeNow - systemUptime)

        isTracking = true
        pedometer.startUpdates(from: dateOfLastReboot) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else {
                if let error = error {
                    DispatchQueue.main.async {
                        self?.eventSink?(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                    }
                }
                return
            }

            var nativeCadence: Double? = nil
            if #available(iOS 9.0, *), let cadence = data.currentCadence {
                nativeCadence = cadence.doubleValue
            }

            let payload: [String: Any] = [
                "rawSteps": data.numberOfSteps.intValue,
                "timestampMs": Int64(data.endDate.timeIntervalSince1970 * 1000),
                "nativeCadenceSps": nativeCadence as Any,
                "source": "iosCoreMotion"
            ]

            DispatchQueue.main.async {
                self.eventSink?(payload)
            }
        }
    }

    private func stopPedometer() {
        if isTracking {
            pedometer.stopUpdates()
            isTracking = false
        }
    }
}

