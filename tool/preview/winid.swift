import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  let layer = w[kCGWindowLayer as String] as? Int ?? 0
  let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
  if owner.lowercased().contains("mitra") && (b["Width"] ?? 0) > 200 {
    print(w[kCGWindowNumber as String] as? Int ?? 0, Int(b["Width"] ?? 0), Int(b["Height"] ?? 0), layer)
  }
}
