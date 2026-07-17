import Cocoa
import FlutterMacOS

class WindowControlService {
  static let shared = WindowControlService()
  private var window: NSWindow?

  func setup(window: NSWindow, binaryMessenger: FlutterBinaryMessenger) {
    self.window = window
    let channel = FlutterMethodChannel(
      name: "com.mitra.assistant/window_control",
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self, let window = self.window else {
        result(FlutterError(code: "UNAVAILABLE", message: "Window not available", details: nil))
        return
      }

      switch call.method {
      case "setSharingTypeNone":
        window.sharingType = .readWrite
        result(true)
      case "setSharingTypeReadWrite":
        window.sharingType = .readWrite
        result(true)
      case "panicHide":
        window.orderOut(nil)
        result(true)
      case "showWindow":
        window.makeKeyAndOrderFront(nil)
        result(true)
      case "setAlwaysOnTop":
        if let flag = call.arguments as? Bool {
          window.level = flag ? .floating : .normal
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected boolean", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
