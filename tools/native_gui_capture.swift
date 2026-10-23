import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor final class CheckerboardView: NSView {
  var inverted = false
  override func draw(_ dirtyRect: NSRect) {
    let colors = [NSColor(srgbRed:0.20, green:0.80, blue:0.84, alpha:1),
                  NSColor(srgbRed:0.86, green:0.30, blue:0.79, alpha:1)]
    for row in 0...Int(bounds.height / 48) {
      for col in 0...Int(bounds.width / 48) {
        colors[(row + col + (inverted ? 1 : 0)) % 2].setFill()
        NSRect(x:CGFloat(col*48), y:CGFloat(row*48), width:48, height:48).fill()
      }
    }
  }
}

// Same executable preflights and captures. No permission request or focus API.
@main struct Probe {
  @MainActor static func main() async {
    var backdrop: NSWindow?
    defer { backdrop?.orderOut(nil); backdrop?.close() }
    do {
      let pid = Int32(CommandLine.arguments[1])!
      if CommandLine.arguments[2] == "--request-close" {
        guard let app = NSRunningApplication(processIdentifier:pid), !app.isTerminated else {
          report(["status":"CLOSE_REQUEST_REFUSED", "reason":"owned_pid_not_running_application", "owner_pid":pid]); return
        }
        let sent = app.terminate()
        report(["status":sent ? "CLOSE_REQUEST_SENT" : "CLOSE_REQUEST_REFUSED", "owner_pid":pid,
          "method":"NSRunningApplication.terminate normal application Quit", "handler_handled":"unknown",
          "request_return_does_not_prove_exit":true,"physical_red_button_test":false]); return
      }
      let output = CommandLine.arguments[2]
      let palette = Int(CommandLine.arguments[3])!
      let screens = NSScreen.screens.map { ["x": $0.frame.origin.x, "y": $0.frame.origin.y,
        "width": $0.frame.width, "height": $0.frame.height, "scale": $0.backingScaleFactor] }
      guard CGPreflightScreenCaptureAccess() else {
        report(["status":"ENVIRONMENT_UNAVAILABLE", "reason":"screen_capture_preflight_denied", "screens":screens]); return
      }
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly:true)
      guard let window = content.windows.first(where: {$0.owningApplication?.processID == pid && $0.windowLayer == 0 && $0.frame.width > 20 && $0.frame.height > 20}),
        let display = content.displays.first(where: {$0.frame.intersects(window.frame)}),
        let mainScreen = NSScreen.screens.first else {
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"no_visible_pid_window", "screens":screens]); return
      }
      let scale = CGFloat(display.width) / display.frame.width
      let backgroundRect = window.frame.insetBy(dx:-16/scale, dy:-16/scale).intersection(display.frame)
      // SCWindow uses global top-left, AppKit uses bottom-left based on main screen.
      let nativeRect = NSRect(x:backgroundRect.minX, y:mainScreen.frame.maxY-backgroundRect.maxY,
                              width:backgroundRect.width, height:backgroundRect.height)
      _ = NSApplication.shared
      NSApplication.shared.setActivationPolicy(.accessory)
      let board = NSWindow(contentRect:nativeRect, styleMask:.borderless, backing:.buffered, defer:false)
      backdrop = board
      board.isReleasedWhenClosed=false; board.isOpaque=true; board.hasShadow=false
      board.ignoresMouseEvents=true; board.level = .normal
      let view = CheckerboardView(frame:NSRect(origin:.zero,size:nativeRect.size))
      view.inverted = palette == 2
      board.contentView=view
      board.order(.below, relativeTo:Int(window.windowID))
      board.displayIfNeeded(); view.display()
      try await Task.sleep(nanoseconds:350_000_000)
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String:Any]] ?? []
      let ids = list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue }
      guard let gameOrder=ids.firstIndex(of:Int(window.windowID)), let boardOrder=ids.firstIndex(of:board.windowNumber), gameOrder + 1 == boardOrder else {
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"backdrop_z_order_unverified"]); return
      }
      // Horizontal center, full vertical sky-to-ground span plus available external control strips.
      let width = min(backgroundRect.width,720/scale)
      let area = CGRect(x:backgroundRect.midX-width/2,y:backgroundRect.minY,width:width,height:backgroundRect.height)
      guard area.width*area.height*scale*scale <= 16000000 else {
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"capture_dimensions_exceed_safety_limit"]); return
      }
      let config = SCStreamConfiguration()
      config.sourceRect = CGRect(x:area.minX-display.frame.minX,y:area.minY-display.frame.minY,width:area.width,height:area.height)
      config.width=Int(area.width*scale); config.height=Int(area.height*scale);config.showsCursor=false
      let filter = SCContentFilter(display:display, excludingWindows:[])
      let image = try await SCScreenshotManager.captureImage(contentFilter:filter, configuration:config)
      guard let data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else {throw NSError(domain:"png",code:1)}
      try data.write(to:URL(fileURLWithPath:output),options:.atomic)
      report(["status":"CAPTURE_READY", "screens":screens,"owner_pid":pid,"window_id":window.windowID,
        "window_width_points":window.frame.width,"window_height_points":window.frame.height,
        "display_scale":scale,"pixel_width":image.width,"pixel_height":image.height,
        "palette":palette,"colors":["#33CCD6","#DB4DC9"],"checker_points":48,"display_frame":[display.frame.minX,display.frame.minY,display.frame.width,display.frame.height],"backdrop_frame":[backgroundRect.minX,backgroundRect.minY,backgroundRect.width,backgroundRect.height],"backdrop_id":board.windowNumber,"game_z_index":gameOrder,"backdrop_z_index":boardOrder,"directly_behind_target":true,"backdrop_level":board.level.rawValue,
        "top_control_pixels":max(0,(window.frame.minY-area.minY)*scale),"bottom_control_pixels":max(0,(area.maxY-window.frame.maxY)*scale),
        "crop_x":area.minX,"crop_y":area.minY,"capture":"composited desktop center native pixels full vertical scene plus available checkerboard control strips"])
    } catch { report(["status":"CAPTURE_INCONCLUSIVE", "reason":String(describing:error)]) }
  }
  static func report(_ object:[String:Any]) {
    let data=try! JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])
    print(String(data:data,encoding:.utf8)!)
  }
}
