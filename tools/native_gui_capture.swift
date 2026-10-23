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
      guard CommandLine.arguments.count >= 3, let pid = Int32(CommandLine.arguments[1]), pid > 0 else {
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"invalid_arguments"]); return
      }
      if CommandLine.arguments[2] == "--request-close" {
        guard let app = NSRunningApplication(processIdentifier:pid), !app.isTerminated else {
          report(["status":"CLOSE_REQUEST_REFUSED", "reason":"owned_pid_not_running_application", "owner_pid":pid]); return
        }
        let sent = app.terminate()
        report(["status":sent ? "CLOSE_REQUEST_SENT" : "CLOSE_REQUEST_REFUSED", "owner_pid":pid,
          "method":"NSRunningApplication.terminate normal application Quit", "handler_handled":"unknown",
          "request_return_does_not_prove_exit":true,"physical_red_button_test":false]); return
      }
      let geometryOnly = CommandLine.arguments[2] == "--geometry-only"
      guard let mainScreen = NSScreen.screens.first else {
        report(["status":"ENVIRONMENT_UNAVAILABLE", "reason":"no_screen"]); return
      }
      // AppKit frames are bottom-origin; CG/SC global frames are top-origin points.
      func cgFrame(_ rect: CGRect) -> CGRect {
        CGRect(x:rect.minX, y:mainScreen.frame.maxY-rect.maxY, width:rect.width, height:rect.height)
      }
      let screens: [[String:Any]] = NSScreen.screens.map {
        let frame = cgFrame($0.frame)
        return ["x":frame.minX,"y":frame.minY,"width":frame.width,"height":frame.height,
          "scale":$0.backingScaleFactor,"work_area":frameArray(cgFrame($0.visibleFrame)),"coordinate_units":"points"]
      }
      // This read-only geometry branch never calls SCShareableContent (which can trigger TCC).
      if geometryOnly {
        let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String:Any]] ?? []
        for entry in entries {
          guard (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
            (entry[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
            let id = entry[kCGWindowNumber as String] as? NSNumber,
            let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation:bounds as CFDictionary), frame.width > 20, frame.height > 20,
            let screen = targetScreen(frame, mainScreen:mainScreen) else { continue }
          var result = geometry(pid:pid, windowID:id.uint32Value, frame:frame, screen:screen, mainScreen:mainScreen, source:"CGWindowListCopyWindowInfo.kCGWindowBounds", screens:screens)
          result["status"] = "GEOMETRY_READY"
          report(result); return
        }
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"no_visible_pid_window", "screens":screens]); return
      }
      guard CommandLine.arguments.count >= 4, let palette = Int(CommandLine.arguments[3]) else {
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"invalid_capture_arguments"]); return
      }
      let output = CommandLine.arguments[2]
      guard CGPreflightScreenCaptureAccess() else {
        report(["status":"ENVIRONMENT_UNAVAILABLE", "reason":"screen_capture_preflight_denied", "screens":screens]); return
      }
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly:true)
      guard let window = content.windows.first(where: {$0.owningApplication?.processID == pid && $0.windowLayer == 0 && $0.frame.width > 20 && $0.frame.height > 20}),
        let screen = targetScreen(window.frame, mainScreen:mainScreen),
        let display = content.displays.first(where: { $0.displayID == (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value }) else {
        report(["status":"CAPTURE_INCONCLUSIVE", "reason":"no_visible_pid_window", "screens":screens]); return
      }
      var metadata = geometry(pid:pid, windowID:window.windowID, frame:window.frame, screen:screen, mainScreen:mainScreen, source:"SCWindow.frame (outer only)", screens:screens)
      let scale = screen.backingScaleFactor
      // A single-display capture must contain the entire window, never silently crop it.
      guard display.frame.contains(window.frame) else {
        metadata["status"]="CAPTURE_INCONCLUSIVE"; metadata["reason"]="full_target_window_not_on_single_display"; report(metadata); return
      }
      let backgroundRect = window.frame.insetBy(dx:-16/scale, dy:-16/scale).intersection(display.frame)
      // Require integer native-pixel extents rather than silently resampling fractional geometry.
      let area = backgroundRect
      guard abs(area.width*scale-(area.width*scale).rounded()) < 0.001,
        abs(area.height*scale-(area.height*scale).rounded()) < 0.001 else {
        metadata["status"]="CAPTURE_INCONCLUSIVE"; metadata["reason"]="non_integral_native_pixel_extent"; report(metadata); return
      }
      let pixelWidth = Int((area.width*scale).rounded())
      let pixelHeight = Int((area.height*scale).rounded())
      guard pixelWidth > 0, pixelHeight > 0, Double(pixelWidth)*Double(pixelHeight) <= 16000000 else {
        metadata["status"]="CAPTURE_INCONCLUSIVE"; metadata["reason"]="capture_dimensions_exceed_safety_limit"; report(metadata); return
      }
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
      let config = SCStreamConfiguration()
      config.sourceRect = CGRect(x:area.minX-display.frame.minX,y:area.minY-display.frame.minY,width:area.width,height:area.height)
      config.width=pixelWidth; config.height=pixelHeight;config.showsCursor=false
      let filter = SCContentFilter(display:display, excludingWindows:[])
      let image = try await SCScreenshotManager.captureImage(contentFilter:filter, configuration:config)
      guard image.width == pixelWidth, image.height == pixelHeight else {
        metadata["status"]="CAPTURE_INCONCLUSIVE"; metadata["reason"]="unexpected_capture_pixel_dimensions"; report(metadata); return
      }
      guard let data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else {throw NSError(domain:"png",code:1)}
      try data.write(to:URL(fileURLWithPath:output),options:.atomic)
      let captured: [String:Any] = ["status":"CAPTURE_READY", "screens":screens,"owner_pid":pid,"window_id":window.windowID,
        "window_width_points":window.frame.width,"window_height_points":window.frame.height,
        "display_scale":scale,"pixel_width":image.width,"pixel_height":image.height,
        "palette":palette,"colors":["#33CCD6","#DB4DC9"],"checker_points":48,"display_frame":[display.frame.minX,display.frame.minY,display.frame.width,display.frame.height],"backdrop_frame":[backgroundRect.minX,backgroundRect.minY,backgroundRect.width,backgroundRect.height],"backdrop_id":board.windowNumber,"game_z_index":gameOrder,"backdrop_z_index":boardOrder,"directly_behind_target":true,"backdrop_level":board.level.rawValue,
        "top_control_pixels":max(0,(window.frame.minY-area.minY)*scale),"bottom_control_pixels":max(0,(area.maxY-window.frame.maxY)*scale),
        "left_control_pixels":max(0,(window.frame.minX-area.minX)*scale),"right_control_pixels":max(0,(area.maxX-window.frame.maxX)*scale),
        "crop_frame":frameArray(area),"crop_x":area.minX,"crop_y":area.minY,"capture":"composited desktop full target window native pixels plus available 16px checkerboard controls; no scaling"]
      metadata.merge(captured) { _, new in new }
      report(metadata)
    } catch { report(["status":"CAPTURE_INCONCLUSIVE", "reason":String(describing:error)]) }
  }
  static func frameArray(_ rect:CGRect) -> [CGFloat] { [rect.minX,rect.minY,rect.width,rect.height] }
  @MainActor static func targetScreen(_ frame:CGRect, mainScreen:NSScreen) -> NSScreen? {
    NSScreen.screens.max { a,b in
      func overlap(_ screen:NSScreen) -> CGFloat {
        let rect=CGRect(x:screen.frame.minX,y:mainScreen.frame.maxY-screen.frame.maxY,width:screen.frame.width,height:screen.frame.height).intersection(frame)
        return rect.isNull ? 0 : rect.width*rect.height
      }
      return overlap(a) < overlap(b)
    }
  }
  @MainActor static func geometry(pid:Int32, windowID:CGWindowID, frame:CGRect, screen:NSScreen, mainScreen:NSScreen, source:String, screens:[[String:Any]]) -> [String:Any] {
    func convert(_ rect:CGRect) -> CGRect { CGRect(x:rect.minX,y:mainScreen.frame.maxY-rect.maxY,width:rect.width,height:rect.height) }
    let screenFrame=convert(screen.frame)
    return ["owner_pid":pid,"window_id":windowID,"screens":screens,
      "outer_frame":frameArray(frame),"client_frame":NSNull(),"screen_frame":frameArray(screenFrame),"work_area":frameArray(convert(screen.visibleFrame)),
      "coordinate_units":"points","coordinate_origin":"global_top_left","backing_scale":screen.backingScaleFactor,"dpi":NSNull(),
      "outer_geometry_source":source,"client_geometry_source":"unavailable_without_AX_or_app_instrumentation; outer_is_not_client",
      "window_width_points":frame.width,"window_height_points":frame.height,"window_fully_onscreen":screenFrame.contains(frame),
      "client_fully_onscreen":NSNull(),"display_scale":screen.backingScaleFactor]
  }
  static func report(_ object:[String:Any]) {
    let data=try! JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])
    print(String(data:data,encoding:.utf8)!)
  }
}
