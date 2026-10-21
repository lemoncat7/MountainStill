extends SceneTree
var scene
func _initialize():call_deferred('start')
func start():
 scene=load('res://main.tscn').instantiate();root.add_child(scene)
 await process_frame
 scene.get_window().transparent_bg=false
 scene.strip=true;scene.desktop.transparent_enabled=true
 RenderingServer.set_default_clear_color(Color('#e8e7df'))
