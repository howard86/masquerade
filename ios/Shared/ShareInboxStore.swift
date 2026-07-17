import Foundation

enum ShareInboxError: LocalizedError, Equatable {
  case unavailable
  case unsupported
  case oversized
  case protectedContent

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "The shared inbox is unavailable."
    case .unsupported:
      return "This item is not a supported UTF-8 text file, URL, or text value."
    case .oversized:
      return "This item is larger than 64 KiB."
    case .protectedContent:
      return "Protected content cannot be saved to the shared inbox."
    }
  }
}

struct ShareInboxManifest: Codable, Equatable {
  static let version = 1

  let schemaVersion: Int
  let id: String
  let kind: String
  let createdAt: Int64
  let byteCount: Int
  let sensitive: Bool
  let payload: String?
  let fileName: String?
  let displayName: String?
}

final class ShareInboxStore {
  static let appGroup = "group.dev.howardism.Masquerade"
  static let maximumBytes = 65_536
  static let directoryName = "ShareInbox"

  private let fileManager: FileManager
  private let root: URL

  convenience init() throws {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: Self.appGroup)
    else {
      throw ShareInboxError.unavailable
    }
    try self.init(root: container.appendingPathComponent(Self.directoryName, isDirectory: true))
  }

  init(root: URL, fileManager: FileManager = .default) throws {
    self.fileManager = fileManager
    self.root = root
    try secure(root, directory: true)
    removeStaleOrphans()
  }

  @discardableResult
  func saveText(_ value: String, kind: String) throws -> ShareInboxManifest {
    guard kind == "text" || kind == "url" else { throw ShareInboxError.unsupported }
    let data = Data(value.utf8)
    guard !data.isEmpty else { throw ShareInboxError.unsupported }
    guard data.count <= Self.maximumBytes else { throw ShareInboxError.oversized }
    guard !Self.isProtected(value) else { throw ShareInboxError.protectedContent }
    let manifest = makeManifest(kind: kind, data: data, payload: value)
    try write(manifest)
    return manifest
  }

  @discardableResult
  func saveFile(at source: URL, displayName suggestedName: String? = nil) throws
    -> ShareInboxManifest
  {
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
    let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .nameKey])
    guard values.isRegularFile == true else { throw ShareInboxError.unsupported }
    guard let displayName = suggestedName ?? values.name, Self.validDisplayName(displayName)
    else { throw ShareInboxError.unsupported }
    guard !Self.isProtected(displayName) else { throw ShareInboxError.protectedContent }
    if let size = values.fileSize, size > Self.maximumBytes { throw ShareInboxError.oversized }
    let data = try Data(contentsOf: source, options: .mappedIfSafe)
    guard !data.isEmpty else { throw ShareInboxError.unsupported }
    guard data.count <= Self.maximumBytes else { throw ShareInboxError.oversized }
    guard let text = String(data: data, encoding: .utf8) else { throw ShareInboxError.unsupported }
    guard !Self.isProtected(text) else { throw ShareInboxError.protectedContent }

    let id = UUID().uuidString
    let fileName = "\(id).payload"
    let manifest = makeManifest(
      id: id,
      kind: "file",
      data: data,
      fileName: fileName,
      displayName: displayName
    )
    let destination = root.appendingPathComponent(fileName, isDirectory: false)
    do {
      try data.write(to: destination, options: .atomic)
      try secure(destination)
      try write(manifest)
    } catch {
      try? fileManager.removeItem(at: destination)
      throw error
    }
    return manifest
  }

  func list() -> [(ShareInboxManifest, Data?)] {
    guard
      let urls = try? fileManager.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else { return [] }
    var items: [(ShareInboxManifest, Data?)] = []
    for url in urls where url.pathExtension == "json" {
      guard let data = try? Data(contentsOf: url),
        let manifest = try? JSONDecoder().decode(ShareInboxManifest.self, from: data),
        valid(manifest)
      else { continue }
      if manifest.kind == "file" {
        guard let fileData = fileData(for: manifest) else { continue }
        items.append((manifest, fileData))
      } else {
        items.append((manifest, nil))
      }
    }
    return items.sorted {
      $0.0.createdAt == $1.0.createdAt
        ? $0.0.id < $1.0.id
        : $0.0.createdAt < $1.0.createdAt
    }
  }

  @discardableResult
  func remove(id: String) -> Bool {
    guard UUID(uuidString: id) != nil else { return false }
    let manifestURL = root.appendingPathComponent("\(id).json", isDirectory: false)
    guard let data = try? Data(contentsOf: manifestURL),
      let manifest = try? JSONDecoder().decode(ShareInboxManifest.self, from: data),
      manifest.id == id,
      valid(manifest)
    else { return false }
    if let fileName = manifest.fileName {
      let payload = root.appendingPathComponent(fileName, isDirectory: false)
      if fileManager.fileExists(atPath: payload.path) {
        do {
          try fileManager.removeItem(at: payload)
        } catch {
          return false
        }
      }
    }
    do {
      try fileManager.removeItem(at: manifestURL)
      return true
    } catch {
      return false
    }
  }

  func clear() throws {
    if fileManager.fileExists(atPath: root.path) {
      try fileManager.removeItem(at: root)
    }
  }

  static func isProtected(_ value: String) -> Bool {
    if directlyProtected(value) { return true }
    if let decoded = value.removingPercentEncoding,
      decoded != value, directlyProtected(decoded) { return true }

    var base64 = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = base64.count % 4
    if remainder != 1 {
      if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
      if let data = Data(base64Encoded: base64),
        let decoded = String(data: data, encoding: .utf8), directlyProtected(decoded) { return true }
    }

    var bytes = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if bytes.hasPrefix("[") && bytes.hasSuffix("]") {
      bytes.removeFirst()
      bytes.removeLast()
    }
    let tokens = bytes.split(whereSeparator: { $0 == "," || $0.isWhitespace })
    if !tokens.isEmpty {
      let values = tokens.compactMap { UInt8($0) }
      if values.count == tokens.count,
        let decoded = String(data: Data(values), encoding: .utf8), directlyProtected(decoded) { return true }
    }
    return false
  }

  private static func directlyProtected(_ value: String) -> Bool {
    sensitivePatterns.contains { value.range(of: $0, options: .regularExpression) != nil }
  }

  static func validDisplayName(_ value: String) -> Bool {
    !value.isEmpty
      && value.utf16.count <= 255
      && !value.contains("/")
      && !value.contains("\\")
      && value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
  }

  private static let sensitivePatterns = [
    #"(?im)(?:^|[\[\{,?&;])\s*(?:-\s*)?["']?(?:access[-_.]?token|api[-_.]?key|auth[-_.]?token|authorization|client[-_.]?secret|consumer[-_.]?secret|credential(?:s)?|pass(?:word|wd)?|private[-_.]?key|proxy[-_.]?authorization|pwd|refresh[-_.]?token|secret[-_.]?access[-_.]?key|secret(?:[-_.]?key)?|session[-_.]?token|token)["']?\s*[:=]"#,
    #"(?m)^\s*(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*="#,
    #"-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----"#,
    #"eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*"#,
  ]

  private func makeManifest(
    id: String = UUID().uuidString,
    kind: String,
    data: Data,
    payload: String? = nil,
    fileName: String? = nil,
    displayName: String? = nil
  ) -> ShareInboxManifest {
    ShareInboxManifest(
      schemaVersion: ShareInboxManifest.version,
      id: id,
      kind: kind,
      createdAt: Int64(Date().timeIntervalSince1970 * 1000),
      byteCount: data.count,
      sensitive: false,
      payload: payload,
      fileName: fileName,
      displayName: displayName
    )
  }

  private func write(_ manifest: ShareInboxManifest) throws {
    let destination = root.appendingPathComponent("\(manifest.id).json", isDirectory: false)
    let data = try JSONEncoder().encode(manifest)
    try data.write(to: destination, options: .atomic)
    try secure(destination)
  }

  private func fileData(for manifest: ShareInboxManifest) -> Data? {
    guard let fileName = manifest.fileName,
      let data = try? Data(contentsOf: root.appendingPathComponent(fileName, isDirectory: false)),
      data.count == manifest.byteCount,
      let text = String(data: data, encoding: .utf8),
      !Self.isProtected(text)
    else { return nil }
    return data
  }

  private func valid(_ manifest: ShareInboxManifest) -> Bool {
    let shape = switch manifest.kind {
    case "text", "url":
      manifest.payload?.isEmpty == false
        && manifest.fileName == nil
        && manifest.displayName == nil
    case "file":
      manifest.payload == nil
        && manifest.fileName == "\(manifest.id).payload"
        && manifest.displayName.map(Self.validDisplayName) == true
    default:
      false
    }
    return manifest.schemaVersion == ShareInboxManifest.version
      && UUID(uuidString: manifest.id) != nil
      && shape
      && manifest.createdAt > 0
      && manifest.byteCount > 0
      && manifest.byteCount <= Self.maximumBytes
      && manifest.sensitive == false
      && (manifest.payload.map { Data($0.utf8).count == manifest.byteCount && !Self.isProtected($0) }
        ?? (manifest.kind == "file"))
      && (manifest.displayName.map { Self.validDisplayName($0) && !Self.isProtected($0) } ?? true)
  }

  private func secure(_ url: URL, directory: Bool = false) throws {
    if directory {
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    try fileManager.setAttributes(
      [.protectionKey: FileProtectionType.complete],
      ofItemAtPath: url.path
    )
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var secured = url
    try secured.setResourceValues(values)
  }

  private func removeStaleOrphans() {
    guard let urls = try? fileManager.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else { return }
    let referenced = Set(urls.compactMap { url -> String? in
      guard url.pathExtension == "json",
        let data = try? Data(contentsOf: url),
        let manifest = try? JSONDecoder().decode(ShareInboxManifest.self, from: data),
        valid(manifest)
      else { return nil }
      return manifest.fileName
    })
    let cutoff = Date().addingTimeInterval(-300)
    for url in urls where url.pathExtension == "payload" && !referenced.contains(url.lastPathComponent) {
      let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
      if modified.map({ $0 < cutoff }) == true { try? fileManager.removeItem(at: url) }
    }
  }
}
