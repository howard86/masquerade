import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var shareInboxChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareInbox") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "dev.howardism.masquerade/share_inbox",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      do {
        let store = try ShareInboxStore()
        switch call.method {
        case "list":
          result(store.list().map { manifest, fileData in
            var value: [String: Any] = [
              "id": manifest.id,
              "kind": manifest.kind,
              "createdAt": manifest.createdAt,
              "byteCount": manifest.byteCount,
              "sensitive": manifest.sensitive,
            ]
            if let payload = manifest.payload { value["payload"] = payload }
            if let displayName = manifest.displayName { value["filename"] = displayName }
            if manifest.kind == "file", let fileData {
              value["data"] = FlutterStandardTypedData(bytes: fileData)
            }
            return value
          })
        case "remove":
          result((call.arguments as? String).map(store.remove(id:)) ?? false)
        case "clear":
          try store.clear()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "share_inbox_unavailable", message: "Shared inbox unavailable.", details: nil))
      }
    }
    shareInboxChannel = channel
  }
}
