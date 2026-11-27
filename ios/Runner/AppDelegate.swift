import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let notificationChannelName = "com.aetron.app/notifications"
  private var notificationChannel: FlutterMethodChannel?
  private var pendingOpenNotificationSettings = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    protectApplicationDataDirectory()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func protectApplicationDataDirectory() {
    guard let documentsUrl = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else { return }

    do {
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: documentsUrl.path
      )
    } catch {
      NSLog("Aetron could not apply iOS data protection to app storage")
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AetronLiquidGlassPlugin") {
      AetronLiquidGlassPlugin.register(with: registrar)
    }
    WorkoutLiveActivityPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "WorkoutLiveActivityPlugin")!
    )
    AetronStepSensorPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "AetronStepSensorPlugin")!
    )
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AetronNotificationBridge") {
      let channel = FlutterMethodChannel(
        name: Self.notificationChannelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleNotificationMethod(call, result: result)
      }
      notificationChannel = channel
    }
  }

  private func handleNotificationMethod(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "getAuthorizationStatus":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let status: String
        switch settings.authorizationStatus {
        case .notDetermined:
          status = "notDetermined"
        case .denied:
          status = "denied"
        case .authorized:
          status = "authorized"
        case .provisional:
          status = "provisional"
        case .ephemeral:
          status = "ephemeral"
        @unknown default:
          status = "denied"
        }
        DispatchQueue.main.async {
          result(status)
        }
      }

    case "requestAuthorization":
      var options: UNAuthorizationOptions = [.alert, .badge, .sound]
      if #available(iOS 12.0, *) {
        options.insert(.providesAppNotificationSettings)
      }
      UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
        DispatchQueue.main.async {
          result(granted)
        }
      }

    case "openNotificationSettings":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let openSystemPage = {
          DispatchQueue.main.async {
            if #available(iOS 16.0, *),
               let notifUrl = URL(string: UIApplication.openNotificationSettingsURLString),
               UIApplication.shared.canOpenURL(notifUrl) {
              UIApplication.shared.open(notifUrl, options: [:]) { success in
                result(success)
              }
              return
            }
            if let appUrl = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(appUrl) {
              UIApplication.shared.open(appUrl, options: [:]) { success in
                result(success)
              }
              return
            }
            result(false)
          }
        }

        if settings.authorizationStatus == .notDetermined {
          var options: UNAuthorizationOptions = [.alert, .badge, .sound]
          if #available(iOS 12.0, *) {
            options.insert(.providesAppNotificationSettings)
          }
          UNUserNotificationCenter.current().requestAuthorization(options: options) { _, _ in
            openSystemPage()
          }
        } else {
          openSystemPage()
        }
      }

    case "consumePendingOpenNotificationSettings":
      let shouldOpen = pendingOpenNotificationSettings
      pendingOpenNotificationSettings = false
      result(shouldOpen)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 12.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    openSettingsFor notification: UNNotification?
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if let channel = self.notificationChannel {
        channel.invokeMethod("openInAppNotificationSettings", arguments: nil)
      } else {
        self.pendingOpenNotificationSettings = true
      }
    }
  }
}
