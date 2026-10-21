extends SceneTree
## Real GPU regression, not valid under --headless (dummy renderer).
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	print("PORTAL_GPU ","PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run():
	if DisplayServer.get_name()=="headless":
		printerr("PORTAL_GPU requires a supported native graphics session");quit(2);return
	var viewport=SubViewport.new();viewport.size=Vector2i(128,64);viewport.transparent_bg=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var pixels=Image.create(32,32,false,Image.FORMAT_RGBA8)
	pixels.fill(Color(.4,.6,.8,.65))
	var texture=ImageTexture.create_from_image(pixels)
	var plain=TextureRect.new();plain.texture=texture;plain.size=Vector2(32,32);plain.position=Vector2(8,8);viewport.add_child(plain)
	var portal=TextureRect.new();portal.texture=texture;portal.size=Vector2(32,32);portal.position=Vector2(64,8);viewport.add_child(portal)
	var material=ShaderMaterial.new();material.shader=load("res://scripts/portal_dissolve.gdshader");material.set_shader_parameter("dissolve",0.0);portal.material=material
	await process_frame;await RenderingServer.frame_post_draw
	var rendered=viewport.get_texture().get_image()
	var expected=rendered.get_pixel(16,16);var actual=rendered.get_pixel(72,16)
	print("PORTAL_GPU plain=",expected," shader_start=",actual)
	check(absf(expected.r-actual.r)<.01 and absf(expected.g-actual.g)<.01 and absf(expected.b-actual.b)<.01,"portal entry preserves rendered RGB")
	check(absf(expected.a-actual.a)<.01 and actual.a>.5,"portal entry preserves alpha")
	material.set_shader_parameter("dissolve",1.0)
	await process_frame;await RenderingServer.frame_post_draw
	rendered=viewport.get_texture().get_image()
	check(rendered.get_pixel(72,16).a<.01,"full dissolve disappears")
	print("PORTAL_GPU complete failures=",failures)
	viewport.queue_free();await process_frame;quit(1 if failures else 0)
