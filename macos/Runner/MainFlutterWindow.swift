import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Make window background transparent
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    flutterViewController.backgroundColor = NSColor.clear

    // Set level to floating overlay (always on top)
    self.level = .floating
    
    // Use readWrite sharingType so window is properly composited and rendered on screen
    self.sharingType = .readWrite

    // Allow overlay to join all desktop spaces
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register native services with the Flutter engine's binary messenger
    let messenger = flutterViewController.engine.binaryMessenger
    WindowControlService.shared.setup(window: self, binaryMessenger: messenger)
    AudioCaptureService.shared.setup(binaryMessenger: messenger)

    super.awakeFromNib()
  }
}

