import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = NSRect(
      origin: self.frame.origin,
      size: NSSize(width: 1200, height: 800)
    )
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 900, height: 800)
    self.setFrame(windowFrame, display: true)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
