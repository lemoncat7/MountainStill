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
  @MainActor static func main() async {
    var action = "unknown"
    do {
      try officialRunner()
      let args = try arguments()
      action = args["Action"] ?? ""
      guard ["Preflight","Inspect","Key","Click","Capture"].contains(action) else { throw Failure("action_not_allowlisted") }
      try permissions()
      if action == "Preflight" {
        report(["status":"PREFLIGHT_READY","post_event_access":true,"screen_capture_access":true,"permission_requested":false,"input_posted":false]); return
      }
      let t = try await target(args)
      try validate(t,requireForeground:false)
      if action == "Inspect" && NSWorkspace.shared.frontmostApplication?.processIdentifier != t.pid {
        guard let app = NSRunningApplication(processIdentifier:t.pid), app.activate(options:[]) else { throw Failure("ordinary_activation_refused") }
        try await Task.sleep(nanoseconds:300_000_000)
      }
      try validate(t)
      var result:[String:Any] = ["status":"INSPECT_READY","action":action,"owner_pid":t.pid,"window_id":t.id,"outer_frame":array(t.outer),"client_frame":array(t.client),"client_to_screen":[t.client.minX,t.client.minY],"client_geometry_source":"derived_from_SCouter_plus_offline_saved_client","client_geometry_is_os_direct":false,"title_height_points":t.outer.height-540,"coordinate_units":"points_equal_native_pixels_at_scale1","coordinate_origin":"global_top_left","backing_scale":t.scale,"foreground_owned":true,"permission_requested":false,"input_delivery_does_not_prove_callback":true]
      if action == "Key" {
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
      report(["status":"INPUT_UNAVAILABLE","action":action,"reason":(error as? Failure)?.message ?? String(describing:error),"retry_allowed":false,"input_state_uncertain":((error as? Failure)?.message ?? "").hasPrefix("input_state_uncertain_after_down")])
    }
  }
  static func report(_ value:[String:Any]) {
    if let data=try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) { print(String(decoding:data,as:UTF8.self)) }
    else { print("{\"status\":\"INPUT_UNAVAILABLE\",\"reason\":\"json_failed\",\"retry_allowed\":false}") }
  }
}
