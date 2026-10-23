import AppKit
import CoreGraphics
import ScreenCaptureKit

// Same executable performs preflight and capture. Never asks for authorization.
@main struct Probe {
  static func main() async {
    do {
      let pid = Int32(CommandLine.arguments[1])!
      let output = CommandLine.arguments[2]
      let screens = NSScreen.screens.map { ["x": $0.frame.origin.x, "y": $0.frame.origin.y,
        "width": $0.frame.width, "height": $0.frame.height, "scale": $0.backingScaleFactor] }
      guard CGPreflightScreenCaptureAccess() else {
        report(["status":"ENVIRONMENT_UNAVAILABLE", "reason":"screen_capture_preflight_denied", "screens":screens]); return
      }
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly:true)
      guard let window = content.windows.first(where: {$0.owningApplication?.processID == pid && $0.windowLayer == 0 && $0.frame.width > 20 && $0.frame.height > 20}),
        let display = content.displays.first(where: {$0.frame.intersects(window.frame)}) else {
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"no_visible_pid_window", "screens":screens]); return
      }
      // Capture composited DISPLAY, not isolated window; native-pixel bounded crop.
      let area = window.frame.intersection(display.frame)
      let scale = CGFloat(display.width) / display.frame.width
      let width = min(area.width, 720 / scale), height = min(area.height, 480 / scale)
      let rect = CGRect(x:area.minX - display.frame.minX, y:area.minY - display.frame.minY, width:width, height:height)
      let config = SCStreamConfiguration()
      config.sourceRect = rect
      config.width = Int(width * scale); config.height = Int(height * scale)
      config.showsCursor = false
      let filter = SCContentFilter(display:display, excludingWindows:[])
      let image = try await SCScreenshotManager.captureImage(contentFilter:filter, configuration:config)
      let bitmap = NSBitmapImageRep(cgImage:image)
      guard let data = bitmap.representation(using:.png, properties:[:]) else { throw NSError(domain:"png", code:1) }
      try data.write(to:URL(fileURLWithPath:output), options:.atomic)
      report(["status":"CAPTURE_READY", "screens":screens, "window_id":window.windowID,
        "window_width_points":window.frame.width, "window_height_points":window.frame.height,
        "display_scale":scale,"pixel_width":image.width,"pixel_height":image.height,
        "capture":"composited display native-pixel top-left application crop"])
    } catch { report(["status":"CAPTURE_INCONCLUSIVE", "reason":String(describing:error)]) }
  }
  static func report(_ object:[String:Any]) {
    let data = try! JSONSerialization.data(withJSONObject:object, options:[.sortedKeys])
    print(String(data:data, encoding:.utf8)!)
  }
}
