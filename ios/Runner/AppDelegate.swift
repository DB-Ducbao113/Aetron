import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    WorkoutLiveActivityPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "WorkoutLiveActivityPlugin")!
    )
    AetronStepSensorPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "AetronStepSensorPlugin")!
    )
  }
}
