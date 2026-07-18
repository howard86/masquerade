import AppIntents
import CoreSpotlight
import Foundation
import Security
import UIKit
import UniformTypeIdentifiers

final class SavedWorkflowSpotlightIndexer {
  static let shared = SavedWorkflowSpotlightIndexer()
  static let domainIdentifier = "dev.howardism.Masquerade.saved-workflows"
  static let identifierPrefix = "\(domainIdentifier)."

  typealias DeleteDomain = ([String], @escaping (Error?) -> Void) -> Void
  typealias AddItems = ([CSSearchableItem], @escaping (Error?) -> Void) -> Void

  private let queue = DispatchQueue(label: "dev.howardism.masquerade.spotlight")
  private let deleteDomain: DeleteDomain
  private let addItems: AddItems
  private var active = false
  private var pendingItems: [CSSearchableItem]?
  private var pendingCompletions: [(Error?) -> Void] = []

  convenience init(searchableIndex: CSSearchableIndex = .default()) {
    self.init(
      deleteDomain: { domains, completion in
        guard CSSearchableIndex.isIndexingAvailable() else {
          completion(nil)
          return
        }
        searchableIndex.deleteSearchableItems(
          withDomainIdentifiers: domains,
          completionHandler: completion
        )
      },
      addItems: { items, completion in
        guard CSSearchableIndex.isIndexingAvailable() else {
          completion(nil)
          return
        }
        searchableIndex.indexSearchableItems(items, completionHandler: completion)
      }
    )
  }

  init(deleteDomain: @escaping DeleteDomain, addItems: @escaping AddItems) {
    self.deleteDomain = deleteDomain
    self.addItems = addItems
  }

  func replace(
    _ workflows: [AppIntentWorkflow],
    completion: @escaping (Error?) -> Void = { _ in }
  ) {
    let items = Self.searchableItems(for: workflows)
    queue.async {
      self.pendingItems = items
      self.pendingCompletions.append(completion)
      self.startIfNeeded()
    }
  }

  static func searchableItems(for workflows: [AppIntentWorkflow]) -> [CSSearchableItem] {
    AppIntentRequestStore.safeWorkflows(workflows).map { workflow in
      let attributes = CSSearchableItemAttributeSet(itemContentType: "public.item")
      attributes.title = workflow.name
      attributes.displayName = workflow.name
      attributes.contentDescription = "Saved workflow"
      return CSSearchableItem(
        uniqueIdentifier: identifierPrefix + workflow.id,
        domainIdentifier: domainIdentifier,
        attributeSet: attributes
      )
    }
  }

  private func startIfNeeded() {
    guard !active, let items = pendingItems else { return }
    let completions = pendingCompletions
    pendingItems = nil
    pendingCompletions = []
    active = true
    deleteDomain([Self.domainIdentifier]) { [weak self] error in
      self?.queue.async {
        guard let self else { return }
        guard error == nil else {
          self.finish(error, completions: completions)
          return
        }
        guard !items.isEmpty else {
          self.finish(nil, completions: completions)
          return
        }
        self.addItems(items) { [weak self] error in
          self?.queue.async {
            self?.finish(error, completions: completions)
          }
        }
      }
    }
  }

  private func finish(_ error: Error?, completions: [(Error?) -> Void]) {
    active = false
    DispatchQueue.main.async {
      completions.forEach { $0(error) }
    }
    startIfNeeded()
  }
}

enum MasqueradeIntentError: LocalizedError {
  case invalidInput
  case unavailable

  var errorDescription: String? {
    switch self {
    case .invalidInput: "The input could not be processed."
    case .unavailable: "Masquerade could not prepare this action."
    }
  }
}

enum MasqueradeIntentEngine {
  static func formatJSON(_ input: String) throws -> String {
    let data = try checkedData(input)
    let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    let formatted = try JSONSerialization.data(
      withJSONObject: value,
      options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
    )
    guard let output = String(data: formatted, encoding: .utf8) else {
      throw MasqueradeIntentError.invalidInput
    }
    return output
  }

  static func jwtClaimCount(_ token: String) throws -> Int {
    _ = try checkedData(token)
    let segments = token.split(separator: ".", omittingEmptySubsequences: false)
    guard segments.count == 3,
      let header = decodeJWTObject(String(segments[0])),
      let payload = decodeJWTObject(String(segments[1])),
      !header.isEmpty
    else { throw MasqueradeIntentError.invalidInput }
    return payload.count
  }

  static func convertTimestamp(_ input: String) throws -> String {
    _ = try checkedData(input)
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let date: Date
    if let number = Double(value), number.isFinite {
      let magnitude = abs(number)
      let seconds = number / (magnitude >= 1e17 ? 1e9 : magnitude >= 1e14 ? 1e6 : magnitude >= 1e11 ? 1e3 : 1)
      guard seconds.isFinite else { throw MasqueradeIntentError.invalidInput }
      date = Date(timeIntervalSince1970: seconds)
    } else if let parsed = parseISO(value) {
      date = parsed
    } else {
      throw MasqueradeIntentError.invalidInput
    }
    guard date.timeIntervalSince1970.isFinite else { throw MasqueradeIntentError.invalidInput }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  static func secureToken(byteCount: Int = 32) throws -> String {
    guard byteCount > 0 && byteCount <= 64 else { throw MasqueradeIntentError.invalidInput }
    var bytes = [UInt8](repeating: 0, count: byteCount)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw MasqueradeIntentError.unavailable
    }
    return Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  @discardableResult
  static func sendSafeResult(_ value: String) -> Bool {
    guard (try? ShareInboxStore().saveText(value, kind: "text")) != nil else { return false }
    NotificationCenter.default.post(name: .masqueradeAppIntentDidWrite, object: nil)
    return true
  }

  private static func decodeJWTObject(_ segment: String) -> [String: Any]? {
    var value = segment.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = value.count % 4
    guard remainder != 1 else { return nil }
    if remainder > 0 { value += String(repeating: "=", count: 4 - remainder) }
    guard let data = Data(base64Encoded: value),
      let object = try? JSONSerialization.jsonObject(with: data),
      let dictionary = object as? [String: Any]
    else { return nil }
    return dictionary
  }

  private static func checkedData(_ value: String) throws -> Data {
    let data = Data(value.utf8)
    guard !data.isEmpty, data.count <= ShareInboxStore.maximumBytes else {
      throw MasqueradeIntentError.invalidInput
    }
    return data
  }

  private static func parseISO(_ value: String) -> Date? {
    if let date = ISO8601DateFormatter().date(from: value) { return date }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value)
  }
}

@available(iOS 16.0, *)
private protocol ForegroundMasqueradeIntent: AppIntent {}

@available(iOS 16.0, *)
extension ForegroundMasqueradeIntent {
  @available(iOS 26.0, *)
  static var supportedModes: IntentModes { .foreground(.immediate) }
}

@available(iOS 16.0, *)
struct InspectClipboardIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Inspect Clipboard"
  static let openAppWhenRun = true
  static let description = IntentDescription("Inspect clipboard text after you explicitly run this shortcut.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try AppIntentRequestStore().save(action: "inspectClipboard")
    return .result(dialog: "Open Masquerade to inspect the clipboard.")
  }
}

@available(iOS 16.0, *)
struct FormatJSONIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Format JSON"
  static let openAppWhenRun = true
  @Parameter(title: "JSON") var input: String
  static var parameterSummary: some ParameterSummary { Summary("Format JSON") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let output = try MasqueradeIntentEngine.formatJSON(input)
    let sent = MasqueradeIntentEngine.sendSafeResult(output)
    return .result(dialog: sent
      ? "JSON formatted. Open Masquerade to view it."
      : "JSON formatted, but protected content was not stored.")
  }
}

@available(iOS 16.0, *)
struct DecodeJWTIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Decode JWT"
  static let openAppWhenRun = true
  @Parameter(title: "JWT") var token: String
  static var parameterSummary: some ParameterSummary { Summary("Decode JWT") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let count = try MasqueradeIntentEngine.jwtClaimCount(token)
    return .result(dialog: "JWT decoded with \(count) claims. Sensitive content was not stored.")
  }
}

@available(iOS 16.0, *)
struct ConvertTimestampIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Convert Timestamp"
  static let openAppWhenRun = true
  @Parameter(title: "Timestamp") var input: String
  static var parameterSummary: some ParameterSummary { Summary("Convert Timestamp") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let output = try MasqueradeIntentEngine.convertTimestamp(input)
    guard MasqueradeIntentEngine.sendSafeResult(output) else { throw MasqueradeIntentError.unavailable }
    return .result(dialog: "Timestamp converted. Open Masquerade to view it.")
  }
}

@available(iOS 16.0, *)
struct GenerateUUIDIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Generate UUID"
  static let openAppWhenRun = true

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard MasqueradeIntentEngine.sendSafeResult(UUID().uuidString.lowercased()) else {
      throw MasqueradeIntentError.unavailable
    }
    return .result(dialog: "UUID generated. Open Masquerade to view it.")
  }
}

@available(iOS 16.0, *)
struct GenerateSecureTokenIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Generate Secure Token"
  static let openAppWhenRun = true

  func perform() async throws -> some IntentResult & ProvidesDialog {
    UIPasteboard.general.setItems(
      [[UTType.plainText.identifier: try MasqueradeIntentEngine.secureToken()]],
      options: [
        .localOnly: true,
        .expirationDate: Date().addingTimeInterval(120),
      ]
    )
    return .result(dialog: "A secure token was generated and copied. It was not stored.")
  }
}

@available(iOS 16.0, *)
struct SavedWorkflowEntity: AppEntity, Identifiable {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved Workflow")
  static let defaultQuery = SavedWorkflowQuery()

  let id: String
  let name: String
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

@available(iOS 16.0, *)
struct SavedWorkflowQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [SavedWorkflowEntity] {
    let wanted = Set(identifiers)
    return try workflows().filter { wanted.contains($0.id) }
  }

  func suggestedEntities() async throws -> [SavedWorkflowEntity] { try workflows() }

  private func workflows() throws -> [SavedWorkflowEntity] {
    try AppIntentRequestStore().workflows().map {
      SavedWorkflowEntity(id: $0.id, name: $0.name)
    }
  }
}

@available(iOS 16.0, *)
struct RunSavedWorkflowIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Run Saved Workflow"
  static let openAppWhenRun = true
  @Parameter(title: "Workflow") var workflow: SavedWorkflowEntity
  @Parameter(title: "Input") var input: String
  static var parameterSummary: some ParameterSummary { Summary("Run \(\.$workflow)") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try AppIntentRequestStore().save(
      action: "runWorkflow",
      workflowID: workflow.id,
      input: input
    )
    return .result(dialog: "Open Masquerade to run the saved workflow.")
  }
}

@available(iOS 16.0, *)
struct ResumeLastSessionIntent: ForegroundMasqueradeIntent {
  static let title: LocalizedStringResource = "Resume Last Session"
  static let openAppWhenRun = true

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try AppIntentRequestStore().save(action: "resumeLastSession")
    return .result(dialog: "Open Masquerade to resume the last safe session.")
  }
}

@available(iOS 16.0, *)
struct MasqueradeShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    // The no-input actions below are the best Action button fits; all eight
    // remain available in Spotlight and Shortcuts without a duplicate index.
    AppShortcut(intent: InspectClipboardIntent(), phrases: ["Inspect clipboard with \(.applicationName)"], shortTitle: "Inspect Clipboard", systemImageName: "clipboard")
    AppShortcut(intent: GenerateUUIDIntent(), phrases: ["Generate UUID with \(.applicationName)"], shortTitle: "Generate UUID", systemImageName: "number")
    AppShortcut(intent: GenerateSecureTokenIntent(), phrases: ["Generate secure token with \(.applicationName)"], shortTitle: "Secure Token", systemImageName: "key")
    AppShortcut(intent: ResumeLastSessionIntent(), phrases: ["Resume last session with \(.applicationName)"], shortTitle: "Resume Session", systemImageName: "arrow.clockwise")
    AppShortcut(intent: FormatJSONIntent(), phrases: ["Format JSON with \(.applicationName)"], shortTitle: "Format JSON", systemImageName: "curlybraces")
    AppShortcut(intent: DecodeJWTIntent(), phrases: ["Decode JWT with \(.applicationName)"], shortTitle: "Decode JWT", systemImageName: "lock.open")
    AppShortcut(intent: ConvertTimestampIntent(), phrases: ["Convert timestamp with \(.applicationName)"], shortTitle: "Convert Timestamp", systemImageName: "clock")
    AppShortcut(intent: RunSavedWorkflowIntent(), phrases: ["Run a saved workflow with \(.applicationName)"], shortTitle: "Run Workflow", systemImageName: "play")
  }
}
