extends SceneTree
const Layout=preload("res://scripts/readability_layout.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
	for dimensions in [Vector2i(800,600),Vector2i(960,540),Vector2i(1200,320),Vector2i(1440,720),Vector2i(1920,1080),Vector2i(2880,1800),Vector2i(3840,2160)]:
		for dpi in [1.0,1.25,1.5,2.0]:
			for requested in [1.0,1.25,1.5,1.75]:
				var scale=Layout.effective_scale(dimensions,requested,dpi)
				var logical=Vector2(dimensions)/scale
				check(logical.x>=959.9 and logical.y>=319.9,"books remain within logical minimum")
				check(scale<=requested*dpi+.001,"adaptive scale never exceeds preference")
				var world=Layout.landscape_rect(logical)
				check(world.size==Vector2(1040,280),"canonical scene units never distort")
				check(is_equal_approx(world.end.y,logical.y),"ground frame bottom anchored")
	var scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://readability_test.json"
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for dimensions in [Vector2(960,320),Vector2(1200,540),Vector2(1600,900)]:
		scene.size=dimensions
		scene._build_nav()
		check(is_equal_approx(scene._world_x(879)-scene._world_x(145),734.0),"building spacing independent of window")
		check(is_equal_approx(scene._world_y(246)-scene._world_y(230),16.0),"ground spacing independent of window")
		scene.desktop.transparent_enabled=false
		var opaque_anchor=scene._diorama_active()
		scene.desktop.transparent_enabled=true
		check(opaque_anchor and scene._diorama_active(),"source anchors independent of compositor transparency")
		scene.desktop.transparent_enabled=false
		var native_before=root.size
		scene.strip=true
		scene._resized()
		check(root.size==native_before,"viewport resize never writes native geometry (no feedback storm)")
		scene.strip=false
		scene._toggle_drawer("settings")
		check(scene.buttons.has("width"),"settings exposes window and type control")
		scene.buttons.width.pressed.emit()
		check(scene.drawer_name=="display","display page opens")
		check(scene._drawer_rect().end.x<=scene.size.x,"display page fits")
		var previous=float(scene.state.settings.ui_scale)
		scene._change_readability(-.25)
		check(float(scene.state.settings.ui_scale)==clampf(previous-.25,1,1.75),"scale change stored")
		scene._toggle_drawer("settings")
		scene._toggle_drawer("display")
		check(scene.buttons.has("scale_up"),"reopening retains scaling controls")
		scene._close_drawer()
	scene.queue_free()
	await process_frame
	print("Readability layout: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
