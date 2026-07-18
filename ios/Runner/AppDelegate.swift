import AppIntents
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var shareInboxChannel: FlutterMethodChannel?
  private var appIntentObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    guard let workflows = try? AppIntentRequestStore().workflows() else { return }
    SavedWorkflowSpotlightIndexer.shared.replace(workflows)
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
        case "consumeIntents":
          result(try AppIntentRequestStore().consume().map { request in
            var value: [String: Any] = [
              "id": request.id,
              "action": request.action,
              "createdAt": request.createdAt,
            ]
            if let workflowID = request.workflowID { value["workflowId"] = workflowID }
            if let input = request.input { value["input"] = input }
            return value
          })
        case "syncWorkflows":
          guard let raw = call.arguments as? [[String: Any]] else {
            throw ShareInboxError.unsupported
          }
          let workflows = raw.compactMap { value -> AppIntentWorkflow? in
            guard value.count == 2,
              let id = value["id"] as? String,
              let name = value["name"] as? String
            else { return nil }
            return AppIntentWorkflow(id: id, name: name)
          }
          let safe = try AppIntentRequestStore().syncWorkflows(workflows)
          if #available(iOS 16.0, *) { MasqueradeShortcuts.updateAppShortcutParameters() }
          SavedWorkflowSpotlightIndexer.shared.replace(safe) { error in
            if error == nil {
              result(nil)
            } else {
              result(FlutterError(
                code: "spotlight_unavailable",
                message: "Shortcut search could not be updated.",
                details: nil
              ))
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "share_inbox_unavailable", message: "Shared inbox unavailable.", details: nil))
      }
    }
    shareInboxChannel = channel
    appIntentObserver = NotificationCenter.default.addObserver(
      forName: .masqueradeAppIntentDidWrite,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.shareInboxChannel?.invokeMethod("refreshExternalInputs", arguments: nil)
    }
  }
}
