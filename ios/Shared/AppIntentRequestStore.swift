import Foundation

extension Notification.Name {
  static let masqueradeAppIntentDidWrite = Notification.Name("masqueradeAppIntentDidWrite")
}

struct AppIntentRequest: Codable, Equatable {
  static let version = 1

  let schemaVersion: Int
  let id: String
  let action: String
  let createdAt: Int64
  let workflowID: String?
  let input: String?
}

struct AppIntentWorkflow: Codable, Equatable {
  let id: String
  let name: String
}

final class AppIntentRequestStore {
  static let directoryName = "AppIntentRequests"
  static let workflowsName = "workflows.json"
  static let allowedActions = Set(["inspectClipboard", "runWorkflow", "resumeLastSession"])
  static let maximumAge: TimeInterval = 300

  private let fileManager: FileManager
  private let root: URL

  convenience init() throws {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: ShareInboxStore.appGroup)
    else { throw ShareInboxError.unavailable }
    try self.init(root: container.appendingPathComponent(Self.directoryName, isDirectory: true))
  }

  init(root: URL, fileManager: FileManager = .default) throws {
    self.fileManager = fileManager
    self.root = root
    try secure(root, directory: true)
    removeInvalidOrStaleRequests()
  }

  @discardableResult
  func save(action: String, workflowID: String? = nil, input: String? = nil) throws
    -> AppIntentRequest
  {
    guard Self.allowedActions.contains(action) else { throw ShareInboxError.unsupported }
    if action == "runWorkflow" {
      guard let workflowID, Self.validIdentifier(workflowID), let input else {
        throw ShareInboxError.unsupported
      }
      let data = Data(input.utf8)
      guard !data.isEmpty else { throw ShareInboxError.unsupported }
      guard data.count <= ShareInboxStore.maximumBytes else { throw ShareInboxError.oversized }
      guard !ShareInboxStore.isProtected(input) else { throw ShareInboxError.protectedContent }
    } else if workflowID != nil || input != nil {
      throw ShareInboxError.unsupported
    }
    let request = AppIntentRequest(
      schemaVersion: AppIntentRequest.version,
      id: UUID().uuidString,
      action: action,
      createdAt: Int64(Date().timeIntervalSince1970 * 1000),
      workflowID: workflowID,
      input: input
    )
    let encoded = try JSONEncoder().encode(request)
    guard encoded.count <= ShareInboxStore.maximumBytes else { throw ShareInboxError.oversized }
    let destination = root.appendingPathComponent("\(request.id).json")
    try encoded.write(to: destination, options: .atomic)
    try secure(destination)
    NotificationCenter.default.post(name: .masqueradeAppIntentDidWrite, object: nil)
    return request
  }

  func list() -> [AppIntentRequest] {
    guard
      let urls = try? fileManager.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else { return [] }
    return urls.compactMap(decode).sorted {
      $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
    }
  }

  /// Deletes before returning so a crash in Flutter cannot replay a command.
  func consume() -> [AppIntentRequest] {
    list().filter { remove(id: $0.id) }
  }

  @discardableResult
  func remove(id: String) -> Bool {
    guard UUID(uuidString: id) != nil else { return false }
    let url = root.appendingPathComponent("\(id).json")
    guard let data = try? Data(contentsOf: url),
      let request = try? JSONDecoder().decode(AppIntentRequest.self, from: data),
      request.id == id, valid(request)
    else { return false }
    do {
      try fileManager.removeItem(at: url)
      return true
    } catch {
      return false
    }
  }

  func syncWorkflows(_ workflows: [AppIntentWorkflow]) throws {
    guard workflows.count <= 100,
      workflows.allSatisfy({ Self.validIdentifier($0.id) && Self.validName($0.name) }),
      Set(workflows.map(\.id)).count == workflows.count
    else { throw ShareInboxError.unsupported }
    let encoded = try JSONEncoder().encode(workflows)
    guard encoded.count <= ShareInboxStore.maximumBytes else { throw ShareInboxError.oversized }
    let destination = root.appendingPathComponent(Self.workflowsName)
    try encoded.write(to: destination, options: .atomic)
    try secure(destination)
  }

  func workflows() -> [AppIntentWorkflow] {
    let url = root.appendingPathComponent(Self.workflowsName)
    guard let data = try? Data(contentsOf: url),
      data.count <= ShareInboxStore.maximumBytes,
      let workflows = try? JSONDecoder().decode([AppIntentWorkflow].self, from: data),
      workflows.count <= 100,
      workflows.allSatisfy({ Self.validIdentifier($0.id) && Self.validName($0.name) }),
      Set(workflows.map(\.id)).count == workflows.count
    else { return [] }
    return workflows
  }

  private func valid(_ request: AppIntentRequest) -> Bool {
    guard request.schemaVersion == AppIntentRequest.version,
      UUID(uuidString: request.id) != nil,
      request.createdAt > 0,
      abs(Date().timeIntervalSince1970 - Double(request.createdAt) / 1000) <= Self.maximumAge,
      Self.allowedActions.contains(request.action)
    else { return false }
    if request.action == "runWorkflow" {
      guard let workflowID = request.workflowID, Self.validIdentifier(workflowID),
        let input = request.input, !input.isEmpty,
        Data(input.utf8).count <= ShareInboxStore.maximumBytes,
        !ShareInboxStore.isProtected(input)
      else { return false }
      return true
    }
    return request.workflowID == nil && request.input == nil
  }

  private static func validIdentifier(_ value: String) -> Bool {
    value.range(of: #"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$"#, options: .regularExpression)
      != nil
  }

  private static func validName(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && value.utf16.count <= 80
      && !ShareInboxStore.isProtected(value)
  }

  private func decode(_ url: URL) -> AppIntentRequest? {
    guard url.lastPathComponent != Self.workflowsName,
      url.pathExtension == "json",
      let data = try? Data(contentsOf: url),
      data.count <= ShareInboxStore.maximumBytes,
      let request = try? JSONDecoder().decode(AppIntentRequest.self, from: data),
      url.lastPathComponent == "\(request.id).json",
      valid(request)
    else { return nil }
    return request
  }

  private func removeInvalidOrStaleRequests() {
    guard
      let urls = try? fileManager.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else { return }
    for url in urls where url.lastPathComponent != Self.workflowsName && decode(url) == nil {
      try? fileManager.removeItem(at: url)
    }
  }

  private func secure(_ url: URL, directory: Bool = false) throws {
    if directory { try fileManager.createDirectory(at: url, withIntermediateDirectories: true) }
    try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var secured = url
    try secured.setResourceValues(values)
  }
}
