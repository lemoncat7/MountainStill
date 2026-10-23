import AppKit
import CoreGraphics
import ScreenCaptureKit
import Foundation

// Disposable official-runner probe. Never requests permission or changes TCC/AX.
@main struct NativeInputHelper {
  struct Failure: Error { let message: String; init(_ text: String) { message = text } }
  struct Target {
    let pid: pid_t
    let id: CGWindowID
    let outer: CGRect
    let client: CGRect
    let display: SCDisplay
    let scale: CGFloat
  }
  static func array(_ r: CGRect) -> [CGFloat] { [r.minX,r.minY,r.width,r.height] }
  static func permissions() throws {
    guard CGPreflightPostEventAccess(), CGPreflightScreenCaptureAccess() else { throw Failure("existing_post_event_and_capture_permissions_required") }
  }
  static func number(_ args: [String:String], _ key: String) throws -> Int {
    guard let raw = args[key], let value = Int(raw) else { throw Failure("missing_or_invalid_" + key) }
    return value
  }
  static func arguments() throws -> [String:String] {
    let raw = Array(CommandLine.arguments.dropFirst())
    guard raw.count % 2 == 0 else { throw Failure("expected_named_argument_pairs") }
    let allowed = Set(["Action","TargetPid","WindowId","ClientWidth","ClientHeight","Key","ClientX","ClientY","RoiX","RoiY","RoiWidth","RoiHeight","OutputPath"])
    var result: [String:String] = [:]
    for index in stride(from:0,to:raw.count,by:2) {
      guard raw[index].hasPrefix("-") else { throw Failure("invalid_argument") }
      let key = String(raw[index].dropFirst())
      guard allowed.contains(key), result[key] == nil else { throw Failure("unknown_or_duplicate_argument") }
      result[key] = raw[index+1]
    }
    return result
  }
  static func officialRunner() throws {
    let e = ProcessInfo.processInfo.environment
    guard e["GITHUB_ACTIONS"] == "true", e["RUNNER_ENVIRONMENT"] == "github-hosted", e["GITHUB_REPOSITORY"] == "lemoncat7/MountainStill", e["RUNNER_OS"] == "macOS" else { throw Failure("official_repository_macos_runner_required") }
  }
  @MainActor static func currentWindows(pid: pid_t) -> [(CGWindowID,CGRect)] {
    let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
    return entries.compactMap { item in
      guard (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
        (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
        let id = (item[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
        let dictionary = item[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation:dictionary as CFDictionary), frame.width > 20, frame.height > 20,
        ((item[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0 else { return nil }
      return (id,frame)
    }
  }
  @MainActor static func validate(_ target: Target, requireForeground: Bool = true) throws {
    try permissions()
    guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == target.display.displayID }), screen.backingScaleFactor == 1, CGDisplayBounds(target.display.displayID) == target.display.frame else { throw Failure("display_geometry_or_backing_scale_changed") }
    let windows = currentWindows(pid:target.pid)
    guard windows.count == 1, windows[0].0 == target.id, windows[0].1 == target.outer else { throw Failure("owned_window_identity_or_geometry_changed") }
    guard let app = NSRunningApplication(processIdentifier:target.pid), !app.isTerminated else { throw Failure("target_process_exited") }
    if requireForeground {
      guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid else { throw Failure("target_lost_foreground") }
    }
  }
  static func idleInput(key: CGKeyCode? = nil) throws {
    let flags = CGEventSource.flagsState(.combinedSessionState)
    guard flags.intersection([.maskShift,.maskControl,.maskAlternate,.maskCommand,.maskSecondaryFn]).isEmpty else { throw Failure("modifier_already_down") }
    let modifierKeys: [CGKeyCode] = [54,55,56,58,59,60,61,62,63]
    for code in modifierKeys {
      if CGEventSource.keyState(.combinedSessionState,key:code) { throw Failure("modifier_key_already_down") }
    }
    for raw in UInt32(0)...UInt32(4) {
      guard let button = CGMouseButton(rawValue:raw) else { continue }
      if CGEventSource.buttonState(.combinedSessionState,button:button) { throw Failure("mouse_button_already_down") }
    }
    if let key = key, CGEventSource.keyState(.combinedSessionState,key:key) { throw Failure("requested_key_already_down") }
  }
  @MainActor static func target(_ args:[String:String]) async throws -> Target {
    let rawPID = try number(args,"TargetPid")
    guard rawPID > 0, rawPID <= Int(Int32.max), try number(args,"ClientWidth") == 960, try number(args,"ClientHeight") == 540 else { throw Failure("expected_pid_and_saved_960x540_client") }
    let pid = pid_t(rawPID)
    let content = try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
    let windows = content.windows.filter { $0.owningApplication?.processID == pid && $0.windowLayer == 0 && $0.isOnScreen && $0.frame.width > 20 && $0.frame.height > 20 }
    guard windows.count == 1, let window = windows.first else { throw Failure("unique_visible_normal_owned_window_required") }
    if let raw = args["WindowId"] {
      guard let id = UInt32(raw), id == window.windowID else { throw Failure("window_id_mismatch") }
    } else if args["Action"] != "Inspect" { throw Failure("inspected_window_id_required") }
    guard let screen = NSScreen.screens.first(where: { s in
      let id = (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
      return content.displays.contains { $0.displayID == id && $0.frame.contains(window.frame) }
    }), let screenID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
      let display = content.displays.first(where: { $0.displayID == screenID }), screen.backingScaleFactor == 1 else { throw Failure("full_window_on_single_scale1_screen_required") }
    let title = window.frame.height - 540
    guard window.frame.width == 960, title >= 20, title <= 40,
      [window.frame.minX,window.frame.minY,window.frame.width,window.frame.height].allSatisfy({ $0.isFinite && $0 == $0.rounded() }) else { throw Failure("outer_frame_incompatible_with_saved_client") }
    let client = CGRect(x:window.frame.minX,y:window.frame.minY+title,width:960,height:540)
    return Target(pid:pid,id:window.windowID,outer:window.frame,client:client,display:display,scale:screen.backingScaleFactor)
  }
  static func outputURL(_ path:String?) throws -> URL {
    guard let path = path, path.hasPrefix("/"), let temp = ProcessInfo.processInfo.environment["RUNNER_TEMP"], temp.hasPrefix("/") else { throw Failure("absolute_owned_output_required") }
    let url = URL(fileURLWithPath:path).standardizedFileURL
    let parent = url.deletingLastPathComponent()
    let root = URL(fileURLWithPath:temp).standardizedFileURL
    guard parent.deletingLastPathComponent() == root, parent.lastPathComponent.hasPrefix("mountainstill-input-"), url.pathExtension == "png",
      !FileManager.default.fileExists(atPath:url.path), parent.resolvingSymlinksInPath() == parent,
      (try parent.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])).isDirectory == true,
      (try parent.resourceValues(forKeys:[.isSymbolicLinkKey])).isSymbolicLink != true else { throw Failure("new_png_in_non_symlink_owned_input_directory_required") }
    return url
  }
  @MainActor static func postPair(_ down:CGEvent, _ up:CGEvent, target:Target, key:CGKeyCode? = nil) throws {
    try idleInput(key:key)
    try validate(target)
    down.postToPid(target.pid)
    do {
      // Each post separately preflights permission, exact owner/window geometry, and focus.
      try validate(target)
      up.postToPid(target.pid)
    } catch {
      // CGEvent posts are adjacent but not atomic. Never bypass a failed guard to release.
      throw Failure("input_state_uncertain_after_down; stopped_without_up: " + ((error as? Failure)?.message ?? String(describing:error)))
    }
  }
  // CG is top-origin; AppKit hit-test is bottom-origin. Do not flip the event.
  static func appKitHitPoint(cgPoint: CGPoint, cgBounds: CGRect, appKitBounds: CGRect) throws -> CGPoint {
    let values = [cgPoint.x,cgPoint.y,cgBounds.minX,cgBounds.minY,cgBounds.width,cgBounds.height,
      appKitBounds.minX,appKitBounds.minY,appKitBounds.width,appKitBounds.height,appKitBounds.maxY]
    guard values.allSatisfy({ $0.isFinite && $0 == $0.rounded() }),
      cgBounds.origin == .zero, appKitBounds.origin == .zero,
      cgBounds.width > 0, cgBounds.height > 0, cgBounds.size == appKitBounds.size,
      cgPoint.x >= 0, cgPoint.y >= 0, cgPoint.x < cgBounds.width, cgPoint.y < cgBounds.height else {
      throw Failure("unknown_or_nonintegral_single_screen_coordinate_mapping")
    }
    return CGPoint(x:cgPoint.x,y:appKitBounds.maxY-cgPoint.y)
  }
  static func coordinateSelfTests() throws {
    let small = CGRect(x:0,y:0,width:1024,height:768)
    let large = CGRect(x:0,y:0,width:1920,height:1080)
    guard try appKitHitPoint(cgPoint:CGPoint(x:280,y:583),cgBounds:small,appKitBounds:small) == CGPoint(x:280,y:185),
      try appKitHitPoint(cgPoint:CGPoint(x:280,y:583),cgBounds:large,appKitBounds:large) == CGPoint(x:280,y:497) else {
      throw Failure("coordinate_positive_selftest_failed")
    }
    let cases: [(CGPoint,CGRect,CGRect)] = [
      (CGPoint(x:280,y:583),CGRect(x:1,y:0,width:1024,height:768),small),
      (CGPoint(x:280,y:583),small,CGRect(x:0,y:1,width:1024,height:768)),
      (CGPoint(x:280,y:583),small,large),
      (CGPoint(x:CGFloat.nan,y:583),small,small),
      (CGPoint(x:280,y:583),small,CGRect(x:0,y:0,width:1024,height:CGFloat.nan)),
      (CGPoint(x:-1,y:583),small,small),
      (CGPoint(x:1024,y:583),small,small),
      (CGPoint(x:280,y:768),small,small),
      (CGPoint(x:280.5,y:583),small,small)
    ]
    for item in cases {
      do {
        _ = try appKitHitPoint(cgPoint:item.0,cgBounds:item.1,appKitBounds:item.2)
      } catch { continue }
      throw Failure("coordinate_negative_selftest_failed")
    }
  }
  @MainActor static func sessionHitGuard(_ target: Target, point: CGPoint, diagnostics: inout [String:Any]) throws -> [String:Any] {
    try validate(target)
    guard NSScreen.screens.count == 1, let screen = NSScreen.screens.first,
      screen.backingScaleFactor == 1, target.client.contains(point),
      (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == target.display.displayID else {
      throw Failure("session_click_requires_one_verified_scale1_screen_and_client_point")
    }
    let appKitPoint = try appKitHitPoint(cgPoint:point,cgBounds:CGDisplayBounds(target.display.displayID),appKitBounds:screen.frame)
    guard screen.frame.origin == .zero,
      target.display.frame == CGRect(origin:.zero,size:screen.frame.size) else {
      throw Failure("unknown_screen_origin_or_display_size")
    }
    let hit = NSWindow.windowNumber(at:appKitPoint,belowWindowWithWindowNumber:0)
    diagnostics["hit_window_id"]=hit
    diagnostics["hit_point_appkit"]=[appKitPoint.x,appKitPoint.y]
    diagnostics["click_screen"]=[point.x,point.y]
    let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly],kCGNullWindowID) as? [[String:Any]] ?? []
    let matches = entries.filter { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == hit }
    if let owner = matches.first?[kCGWindowOwnerPID as String] as? NSNumber { diagnostics["hit_owner_pid"]=owner.int32Value }
    else { diagnostics["hit_owner_pid"]=NSNull() }
    guard hit > 0, hit == Int(target.id) else { throw Failure("interactive_hit_target_not_owned_window") }
    guard matches.count == 1,
      (matches[0][kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == target.pid else {
      throw Failure("interactive_hit_owner_pid_unconfirmed")
    }
    return ["hit_window_id":hit,"hit_owner_pid":target.pid,
      "hit_point_appkit":[appKitPoint.x,appKitPoint.y],"click_screen":[point.x,point.y],
      "hit_test":"NSWindow.windowNumber(at:belowWindowWithWindowNumber:0)",
      "hit_test_is_momentary_not_delivery_guarantee":true]
  }
  @MainActor static func guideClickSession(_ args:[String:String], target:Target,
      posted: inout Int, diagnostics: inout [String:Any]) throws {
    guard try number(args,"ClientX") == 268, try number(args,"ClientY") == 514 else {
      throw Failure("only_arrival_guide_client_point_268_514_allowed")
    }
    let point = CGPoint(x:target.client.minX+268,y:target.client.minY+514)
    guard let move = CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left),
      let down = CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left),
      let up = CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left) else {
      throw Failure("session_mouse_event_creation_failed")
    }
    move.flags=[];down.flags=[];up.flags=[]
    down.setIntegerValueField(.mouseEventClickState,value:1)
    up.setIntegerValueField(.mouseEventClickState,value:1)
    diagnostics["route"]="cgSessionEventTap"
    diagnostics["click_client"]=[268,514]
    diagnostics["atomic_pair"]=false
    for event in [move,down,up] {
      // Up must not reject our own down. Ownership/preflight/hit guards still apply.
      if posted < 2 { try idleInput() }
      let hit = try sessionHitGuard(target,point:point,diagnostics:&diagnostics)
      diagnostics.merge(hit) { _,new in new }
      event.post(tap:.cgSessionEventTap)
      posted += 1
      diagnostics["posted_events"]=posted
    }
  }
  @MainActor static func main() async {
    var action = "unknown"
    var sessionPosted = 0
    var sessionDiagnostics: [String:Any] = [:]
    do {
      try officialRunner()
      let args = try arguments()
      action = args["Action"] ?? ""
      guard ["Preflight","Inspect","Key","Click","Capture","GuideClickSession"].contains(action) else { throw Failure("action_not_allowlisted") }
      try permissions()
      if action == "Preflight" {
        try coordinateSelfTests()
        report(["status":"PREFLIGHT_READY","post_event_access":true,"screen_capture_access":true,"permission_requested":false,"input_posted":false,"coordinate_selftests_passed":true,"coordinate_selftests_positive":2,"coordinate_selftests_negative":9]); return
      }
      let t = try await target(args)
      try validate(t,requireForeground:false)
      if action == "Inspect" && NSWorkspace.shared.frontmostApplication?.processIdentifier != t.pid {
        guard let app = NSRunningApplication(processIdentifier:t.pid), app.activate(options:[]) else { throw Failure("ordinary_activation_refused") }
        try await Task.sleep(nanoseconds:300_000_000)
      }
      try validate(t)
      var result:[String:Any] = ["status":"INSPECT_READY","action":action,"owner_pid":t.pid,"window_id":t.id,"outer_frame":array(t.outer),"client_frame":array(t.client),"client_to_screen":[t.client.minX,t.client.minY],"client_geometry_source":"derived_from_SCouter_plus_offline_saved_client","client_geometry_is_os_direct":false,"title_height_points":t.outer.height-540,"coordinate_units":"points_equal_native_pixels_at_scale1","coordinate_origin":"global_top_left","backing_scale":t.scale,"foreground_owned":true,"permission_requested":false,"input_delivery_does_not_prove_callback":true]
      if action == "GuideClickSession" {
        try guideClickSession(args,target:t,posted:&sessionPosted,diagnostics:&sessionDiagnostics)
        result.merge(sessionDiagnostics) { _,new in new }
        result["status"]="INPUT_SENT"
      } else if action == "Key" {
        let keys:[String:CGKeyCode] = ["I":34,"G":5,"Space":49,"Esc":53]
        guard let name = args["Key"], let code = keys[name], let down = CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:true), let up = CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:false) else { throw Failure("invalid_key_or_event") }
        down.flags=[];up.flags=[]
        try postPair(down,up,target:t,key:code)
        result["status"]="INPUT_SENT";result["key"]=name;result["posted_events"]=2
      } else if action == "Click" {
        let x = try number(args,"ClientX"), y = try number(args,"ClientY")
        guard x >= 0, x < 960, y >= 0, y < 540 else { throw Failure("click_outside_derived_client") }
        // SC/CG frames and CGEvent mouse locations share global top-left coordinates.
        let point = CGPoint(x:t.client.minX+CGFloat(x),y:t.client.minY+CGFloat(y))
        guard let down = CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left), let up = CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left) else { throw Failure("mouse_event_creation_failed") }
        down.flags=[];up.flags=[]
        down.setIntegerValueField(.mouseEventClickState,value:1);up.setIntegerValueField(.mouseEventClickState,value:1)
        try postPair(down,up,target:t)
        result["status"]="INPUT_SENT";result["click_client"]=[x,y];result["click_screen"]=[point.x,point.y];result["posted_events"]=2
      } else if action == "Capture" {
        let x = try number(args,"RoiX"), y = try number(args,"RoiY"), w = try number(args,"RoiWidth"), h = try number(args,"RoiHeight")
        guard x >= 0, x < 960, y >= 0, y < 540, w > 0, w <= 960-x, h > 0, h <= 540-y else { throw Failure("roi_must_be_within_derived_client") }
        let output = try outputURL(args["OutputPath"])
        let roi = CGRect(x:t.client.minX+CGFloat(x),y:t.client.minY+CGFloat(y),width:CGFloat(w),height:CGFloat(h))
        let config = SCStreamConfiguration()
        config.sourceRect=CGRect(x:roi.minX-t.display.frame.minX,y:roi.minY-t.display.frame.minY,width:roi.width,height:roi.height)
        config.width=w;config.height=h;config.showsCursor=false
        try validate(t)
        let image = try await SCScreenshotManager.captureImage(contentFilter:SCContentFilter(display:t.display,excludingWindows:[]),configuration:config)
        try validate(t)
        guard image.width == w, image.height == h, let data = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else { throw Failure("unexpected_capture_size_or_png_failure") }
        // Recheck ownership/nonexistence before writing; never replace prior evidence.
        _ = try outputURL(output.path)
        try data.write(to:output,options:.withoutOverwriting)
        result["status"]="CAPTURE_READY";result["roi_client"]=[x,y,w,h];result["roi_screen"]=array(roi);result["pixel_width"]=w;result["pixel_height"]=h
        result["capture"]="native scale1 desktop ROI; no backdrop, resize, or scaling"
      }
      report(result)
    } catch {
      var failure: [String:Any] = ["status":"INPUT_UNAVAILABLE","action":action,"reason":(error as? Failure)?.message ?? String(describing:error),"retry_allowed":false,"input_state_uncertain":((error as? Failure)?.message ?? "").hasPrefix("input_state_uncertain_after_down") || (action == "GuideClickSession" && sessionPosted == 2)]
      if action == "GuideClickSession" {
        failure.merge(sessionDiagnostics) { _,new in new }
        failure["posted_events"]=sessionPosted
        failure["route"]="cgSessionEventTap"
      }
      report(failure)
    }
  }
  static func report(_ value:[String:Any]) {
    if let data=try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) { print(String(decoding:data,as:UTF8.self)) }
    else { print("{\"status\":\"INPUT_UNAVAILABLE\",\"reason\":\"json_failed\",\"retry_allowed\":false}") }
  }
}
