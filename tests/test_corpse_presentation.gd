extends SceneTree
const Corpse=preload("res://scripts/corpse_presentation.gd")
var checks:=0
var failures:=0
func check(condition:bool,label:String):
 checks+=1
 if not condition:failures+=1;printerr("FAIL: "+label)
func _initialize():
 var metadata:Variant=JSON.parse_string(FileAccess.get_file_as_string(Corpse.FALLEN_PATH))
 check(metadata is Dictionary,"Fallen metadata loads")
 for route in ["bamboo_pass","cloud_slope"]:
  var key:String=route+"_boss_authored_fallen_v7"
  var data:Dictionary=metadata.poses[key]
  var body:Dictionary=Corpse._body({},route,true,174.0,true)
  check(not body.is_empty(),route+" real painted fallen key loads")
  check(body.texture.get_size()==Vector2(256,256),route+" canonical source canvas")
  check(is_zero_approx(float(body.rotation)),route+" lying silhouette is not a rotated standing sprite")
  var rect:Rect2=body.rect
  check(is_equal_approx(rect.size.x,rect.size.y),route+" no anisotropic flattening")
  var visible:Rect2=body.visible
  check(visible.size.y/visible.size.x<.57,route+" genuinely low silhouette")
  var scale_value:float=rect.size.x/256.0
  var landmark:Dictionary=data.body_registration
  check(is_equal_approx(float(landmark.diameter)*scale_value,float(landmark.reference_diameter)*174.0/256.0),route+" primary body landmark retains living size")
  var head_ratio:float=float(data.head_diameter)*scale_value/(float(data.reference_head_diameter)*174.0/256.0)
  check(head_ratio>=.5 and head_ratio<=1.05,route+" folded projected head does not swell or disappear")
  check(is_equal_approx(visible.end.y,0.0),route+" authored body rests on ground")
  check(Corpse._body({},route,true,174.0,true)==body,route+" body parameters cached")
 for route in ["creek_bridge","ember_ruins","moon_marsh","summit_gate"]:
  check(Corpse._body({},route,true,174.0,true).is_empty(),route+" does not substitute another species fallen art")
  check(Corpse.PROFILES.has(route),route+" fallback remains configured")
 print("Corpse presentation: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
