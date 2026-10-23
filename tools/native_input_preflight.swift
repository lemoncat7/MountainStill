import Foundation
import CoreGraphics

// Read-only existing-permission preflight: never request TCC, use AX, or post events.
@main struct NativeInputPreflight {
  static func main() {
    let postEvent = CGPreflightPostEventAccess()
    let screenCapture = CGPreflightScreenCaptureAccess()
    let result: [String: Any] = [
      "status": postEvent && screenCapture ? "PREFLIGHT_READY" : "ENVIRONMENT_UNAVAILABLE",
      "post_event_access": postEvent,
      "screen_capture_access": screenCapture,
      "permission_requested": false,
      "input_posted": false,
      "scope": "preflight only; no native input implementation on macOS"
    ]
    do {
      let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
      print(String(decoding: data, as: UTF8.self))
    } catch { print("{\"status\":\"ENVIRONMENT_UNAVAILABLE\",\"reason\":\"preflight_json_failed\"}") }
  }
}
