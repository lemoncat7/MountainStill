extends SceneTree
const Desktop = preload("res://scripts/desktop_mode.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	check(ProjectSettings.get_setting("rendering/gl_compatibility/driver.windows") == "opengl3_angle", "Windows preference is ANGLE")
	check(ProjectSettings.get_setting("rendering/gl_compatibility/fallback_to_native", true), "Engine native fallback remains enabled")
	check(not project.contains("fallback_to_native="), "Do not replace the engine fallback default")
	check(not project.contains("driver.linuxbsd=") and not project.contains("driver.linux=") and not project.contains("driver.macos=") and not project.contains("\ndriver="), "No generic or other-platform driver override")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer is retained")
	check(ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed"), "Layered transparency remains allowed")
	check(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color").a == 0.0, "Clear alpha remains zero")
	var helper = Desktop.new()
	var detached: Dictionary = helper.display_diagnostic()
	check(not detached.window_attached and not detached.pixel_transparency_verified, "Detached diagnostics do not claim visual success")
	helper.attach(root)
	var fields := ["schema", "os", "display_server", "rendering_method", "rendering_driver", "adapter_name", "adapter_vendor", "adapter_api", "window_attached", "native_window_ready", "transparency_requested", "transparency_supported", "helper_transparency_applied", "window_transparent_flag", "viewport_transparent_background", "borderless", "pixel_transparency_verified"]
	var initial: Dictionary = helper.display_diagnostic()
	check(initial.size() == fields.size(), "Diagnostic has only the approved non-secret fields")
	for key in fields:
		check(initial.has(key), "Diagnostic field: " + key)
	check(initial.rendering_driver == RenderingServer.get_current_rendering_driver_name(), "Reports the active engine driver, not the Windows preference")
	check(initial.rendering_method == RenderingServer.get_current_rendering_method(), "Reports actual rendering method")
	check(initial.adapter_name == RenderingServer.get_video_adapter_name(), "Reports adapter model without unique identifier")
	check(initial.transparency_supported == DisplayServer.is_window_transparency_available(), "Support flag is reported without interpreting pixels")
	check(helper._log_display_diagnostic(), "First snapshot is logged")
	check(not helper._log_display_diagnostic(), "Identical snapshot is not logged twice")
	for cycle in range(3):
		var applied: bool = helper.set_transparent(true)
		var current: Dictionary = helper.display_diagnostic()
		check(current.transparency_requested, "Enable request preserved")
		check(current.helper_transparency_applied == applied, "Helper flag agrees with setter result")
		check(not current.pixel_transparency_verified, "Applied flags never claim composed-pixel success")
		check(not helper._log_display_diagnostic(), "Unchanged enable request does not spam log")
		helper.set_strip(true)
		helper.set_strip(false)
		helper.safe_restore()
		var restored: Dictionary = helper.display_diagnostic()
		check(not restored.transparency_requested and not restored.helper_transparency_applied, "Safety restore clears requested and applied transparency")
		check(not restored.window_transparent_flag and not restored.viewport_transparent_background and not restored.borderless, "Safety restore leaves ordinary opaque interactive window")
		check(not helper._log_display_diagnostic(), "Repeated safety state is deduplicated")
	var snapshot: Dictionary = helper.display_diagnostic()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	check(parsed.size() == snapshot.size(), "JSON roundtrip preserves field membership")
	for key in snapshot:
		# Godot JSON parses numeric schema as float; compare its exact value.
		check(parsed.get(key) == snapshot[key], "JSON roundtrip value: " + key)
	helper.dispose()
	check(not helper.display_diagnostic().window_attached, "Disposed diagnostics do not retain window")
	check(helper._last_display_diagnostic.is_empty(), "Disposed snapshot reset")
	print("Display diagnostics: %d checks, %d failures; Windows preference, actual backend, deduplication, and recovery" % [checks, failures])
	quit(1 if failures else 0)
