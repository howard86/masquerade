import MobileCoreServices
import UIKit

final class ShareViewController: UIViewController {
  private let status = UILabel()
  private let done = UIButton(type: .system)
  private var started = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    status.numberOfLines = 0
    status.textAlignment = .center
    status.text = "Saving to Masquerade…"
    done.setTitle("Done", for: .normal)
    done.isHidden = true
    done.addTarget(self, action: #selector(close), for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [status, done])
    stack.axis = .vertical
    stack.spacing = 20
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    capture()
  }

  @objc private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }

  private func capture() {
    guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first else {
      return fail(.unsupported)
    }
    if let provider = item.attachments?.first(where: {
      $0.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String)
    }) {
      return loadFile(provider)
    }
    if let provider = item.attachments?.first(where: {
      $0.hasItemConformingToTypeIdentifier(kUTTypeURL as String)
    }) {
      return loadURL(provider)
    }
    if let provider = item.attachments?.first(where: {
      $0.hasItemConformingToTypeIdentifier(kUTTypePlainText as String)
        || $0.hasItemConformingToTypeIdentifier(kUTTypeText as String)
    }) {
      return loadText(provider)
    }
    if let provider = item.attachments?.first(where: {
      $0.registeredTypeIdentifiers.contains(where: isDataType)
    }), let type = provider.registeredTypeIdentifiers.first(where: isDataType) {
      return loadFile(provider, type: type)
    }
    if let text = item.attributedContentText?.string, !text.isEmpty {
      save { _ = try ShareInboxStore().saveText(text, kind: "text") }
    } else {
      fail(.unsupported)
    }
  }

  private func loadText(_ provider: NSItemProvider) {
    let type = provider.hasItemConformingToTypeIdentifier(kUTTypePlainText as String)
      ? kUTTypePlainText as String : kUTTypeText as String
    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] value, _ in
      let text = (value as? String) ?? (value as? NSAttributedString)?.string
      guard let text else {
        self?.fail(.unsupported)
        return
      }
      self?.save { _ = try ShareInboxStore().saveText(text, kind: "text") }
    }
  }

  private func loadURL(_ provider: NSItemProvider) {
    provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [weak self] value, _ in
      guard let url = value as? URL else {
        self?.fail(.unsupported)
        return
      }
      if url.isFileURL {
        self?.loadFile(provider)
        return
      }
      self?.save { _ = try ShareInboxStore().saveText(url.absoluteString, kind: "url") }
    }
  }

  private func loadFile(_ provider: NSItemProvider, type: String = kUTTypeFileURL as String) {
    provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
      guard let url else {
        self?.fail(.unsupported)
        return
      }
      do {
        _ = try ShareInboxStore().saveFile(at: url, displayName: provider.suggestedName)
        DispatchQueue.main.async { self?.saved() }
      } catch let error as ShareInboxError {
        self?.fail(error)
      } catch {
        self?.fail(.unavailable)
      }
    }
  }

  private func save(_ operation: @escaping () throws -> Void) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        try operation()
        DispatchQueue.main.async { self?.saved() }
      } catch let error as ShareInboxError {
        self?.fail(error)
      } catch {
        self?.fail(.unavailable)
      }
    }
  }

  private func saved() {
    status.text = "Saved. Open Masquerade to continue."
    done.isHidden = false
    UIAccessibility.post(notification: .announcement, argument: status.text)
  }

  private func fail(_ error: ShareInboxError) {
    DispatchQueue.main.async { [weak self] in
      self?.status.text = error.errorDescription
      self?.done.isHidden = false
      UIAccessibility.post(notification: .announcement, argument: self?.status.text)
    }
  }

  private func isDataType(_ identifier: String) -> Bool {
    UTTypeConformsTo(identifier as CFString, kUTTypeData)
      && !UTTypeConformsTo(identifier as CFString, kUTTypeImage)
      && !UTTypeConformsTo(identifier as CFString, kUTTypeMovie)
      && !UTTypeConformsTo(identifier as CFString, kUTTypeAudio)
  }
}
