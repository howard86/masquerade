import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: root)
  }

  func testStoreRoundTripsAndRemovesSafeHandoffs() throws {
    let store = try ShareInboxStore(root: root)
    let text = try store.saveText("https://example.com", kind: "url")
    let source = root.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).json")
    try Data(#"{"ok":true}"#.utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let file = try store.saveFile(at: source)

    let items = store.list()
    XCTAssertEqual(Set(items.map(\.0.id)), Set([text.id, file.id]))
    XCTAssertNil(items.first(where: { $0.0.id == text.id })?.1)
    XCTAssertEqual(
      items.first(where: { $0.0.id == file.id })?.1,
      Data(#"{"ok":true}"#.utf8)
    )
    let protection = try FileManager.default.attributesOfItem(atPath: root.path)[.protectionKey]
      as? FileProtectionType
    #if targetEnvironment(simulator)
      XCTAssertTrue(protection == nil || protection == .complete)
    #else
      XCTAssertEqual(protection, .complete)
    #endif
    XCTAssertTrue(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)

    XCTAssertTrue(store.remove(id: text.id))
    XCTAssertEqual(store.list().map(\.0.id), [file.id])
    XCTAssertTrue(store.remove(id: file.id))
    XCTAssertTrue(store.list().isEmpty)
  }

  func testProtectedValuesNeverCreateHandoffFiles() throws {
    let store = try ShareInboxStore(root: root)
    let fixtures = [
      "password=do-not-persist",
      "-----BEGIN PRIVATE KEY-----",
      "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature",
      "export SAFE=value",
      "cGFzc3dvcmQ9ZG8tbm90LXBlcnNpc3Q=",
      "password%3Ddo-not-persist",
      "[112, 97, 115, 115, 119, 111, 114, 100, 61, 120]",
    ]
    for fixture in fixtures {
      XCTAssertThrowsError(try store.saveText(fixture, kind: "text")) { error in
        XCTAssertEqual(error as? ShareInboxError, .protectedContent)
      }
    }
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
  }

  func testConcurrentSavesKeepUniqueAtomicItems() throws {
    let store = try ShareInboxStore(root: root)
    let lock = NSLock()
    var errors: [Error] = []
    DispatchQueue.concurrentPerform(iterations: 8) { index in
      do {
        try store.saveText("safe value \(index)", kind: "text")
      } catch {
        lock.lock()
        errors.append(error)
        lock.unlock()
      }
    }

    XCTAssertTrue(errors.isEmpty)
    let items = store.list()
    XCTAssertEqual(items.count, 8)
    XCTAssertEqual(Set(items.map(\.0.id)).count, 8)
    for item in items { XCTAssertTrue(store.remove(id: item.0.id)) }
    XCTAssertTrue(store.list().isEmpty)
  }

  func testRejectsOversizedAndNonUTF8FilesBeforeWriting() throws {
    let store = try ShareInboxStore(root: root)
    let parent = root.deletingLastPathComponent()
    let oversized = parent.appendingPathComponent(UUID().uuidString)
    let binary = parent.appendingPathComponent(UUID().uuidString)
    try Data(repeating: 65, count: ShareInboxStore.maximumBytes + 1).write(to: oversized)
    try Data([0xff, 0xfe]).write(to: binary)
    defer {
      try? FileManager.default.removeItem(at: oversized)
      try? FileManager.default.removeItem(at: binary)
    }

    XCTAssertThrowsError(try store.saveFile(at: oversized)) { error in
      XCTAssertEqual(error as? ShareInboxError, .oversized)
    }
    XCTAssertThrowsError(try store.saveFile(at: binary)) { error in
      XCTAssertEqual(error as? ShareInboxError, .unsupported)
    }
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
  }

  func testProtectedFilenameIsRejectedBeforeWriting() throws {
    let store = try ShareInboxStore(root: root)
    let source = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
    try Data("safe contents".utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }

    XCTAssertThrowsError(
      try store.saveFile(at: source, displayName: "password=do-not-persist.txt")
    ) { error in
      XCTAssertEqual(error as? ShareInboxError, .protectedContent)
    }
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
  }

  func testPayloadBoundaryMatchesFlutterProtectionInspectionLimit() throws {
    let store = try ShareInboxStore(root: root)
    let boundary = String(repeating: "a", count: ShareInboxStore.maximumBytes)
    let saved = try store.saveText(boundary, kind: "text")
    XCTAssertEqual(saved.byteCount, 65_536)
    XCTAssertTrue(store.remove(id: saved.id))

    XCTAssertThrowsError(try store.saveText(boundary + "a", kind: "text")) { error in
      XCTAssertEqual(error as? ShareInboxError, .oversized)
    }
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
  }

  func testFilenameBoundaryMatchesDartUTF16Length() {
    XCTAssertTrue(ShareInboxStore.validDisplayName(String(repeating: "😀", count: 127)))
    XCTAssertFalse(ShareInboxStore.validDisplayName(String(repeating: "😀", count: 128)))
  }

  func testAppIntentStoreConsumesOnceAndRejectsProtectedInput() throws {
    let store = try AppIntentRequestStore(root: root)
    try store.syncWorkflows([AppIntentWorkflow(id: "workflow-1", name: "JSON cleanup")])
    try store.save(action: "inspectClipboard")
    try store.save(action: "runWorkflow", workflowID: "workflow-1", input: #"{"ok":true}"#)

    XCTAssertEqual(store.workflows(), [AppIntentWorkflow(id: "workflow-1", name: "JSON cleanup")])
    XCTAssertEqual(store.consume().map(\.action), ["inspectClipboard", "runWorkflow"])
    XCTAssertTrue(store.consume().isEmpty)
    XCTAssertThrowsError(
      try store.save(
        action: "runWorkflow",
        workflowID: "workflow-1",
        input: "password=do-not-persist"
      )
    ) { error in
      XCTAssertEqual(error as? ShareInboxError, .protectedContent)
    }
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: root.path),
      [AppIntentRequestStore.workflowsName]
    )
  }

  func testAppIntentStoreDeletesAliasedRequestsBeforeTheyCanReplay() throws {
    _ = try AppIntentRequestStore(root: root)
    let request = AppIntentRequest(
      schemaVersion: AppIntentRequest.version,
      id: UUID().uuidString,
      action: "resumeLastSession",
      createdAt: Int64(Date().timeIntervalSince1970 * 1000),
      workflowID: nil,
      input: nil
    )
    let alias = root.appendingPathComponent("\(UUID().uuidString).json")
    try JSONEncoder().encode(request).write(to: alias)

    let reloaded = try AppIntentRequestStore(root: root)
    XCTAssertTrue(reloaded.list().isEmpty)
    XCTAssertFalse(FileManager.default.fileExists(atPath: alias.path))
  }

  func testAppIntentEngineExecutesSyntheticFixturesWithoutLeakingSecrets() throws {
    XCTAssertEqual(try MasqueradeIntentEngine.formatJSON("42"), "42")
    XCTAssertEqual(
      try MasqueradeIntentEngine.formatJSON(#"{"b":2,"a":1}"#),
      "{\n  \"a\" : 1,\n  \"b\" : 2\n}"
    )
    let jwt = "eyJhbGciOiJub25lIn0.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9."
    XCTAssertEqual(try MasqueradeIntentEngine.jwtClaimCount(jwt), 2)

    let expected = try MasqueradeIntentEngine.convertTimestamp("1700000000")
    XCTAssertEqual(try MasqueradeIntentEngine.convertTimestamp("1700000000000"), expected)
    XCTAssertEqual(try MasqueradeIntentEngine.convertTimestamp("1700000000000000"), expected)
    XCTAssertEqual(try MasqueradeIntentEngine.convertTimestamp("1700000000000000000"), expected)
    XCTAssertEqual(try MasqueradeIntentEngine.convertTimestamp(expected), expected)

    let first = try MasqueradeIntentEngine.secureToken()
    let second = try MasqueradeIntentEngine.secureToken()
    XCTAssertNotEqual(first, second)
    XCTAssertNotNil(first.range(of: #"^[A-Za-z0-9_-]{43}$"#, options: .regularExpression))
    XCTAssertFalse(first.contains("password"))

    let oversized = String(repeating: "a", count: ShareInboxStore.maximumBytes + 1)
    XCTAssertThrowsError(try MasqueradeIntentEngine.formatJSON(oversized))
    XCTAssertThrowsError(try MasqueradeIntentEngine.jwtClaimCount(oversized))
    XCTAssertThrowsError(try MasqueradeIntentEngine.convertTimestamp(oversized))
  }

  func testShortcutCatalogStaysFocused() {
    if #available(iOS 16.0, *) {
      XCTAssertEqual(MasqueradeShortcuts.appShortcuts.count, 8)
    }
  }

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}
