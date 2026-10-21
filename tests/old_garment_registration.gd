extends "res://scripts/character_sidewalk.gd"
## QA only: current identical skeleton/guard, pre-fix garment and sleeve maps.
func _draw_arm(host:CanvasItem,arm:Dictionary,visual:Dictionary,tint:Color)->void:
 _draw_limb(host,assets.arm,arm,true,tint)
 var sleeve:=str(visual.get("chest","")).replace("chest_","sleeve_")
 if assets.has(sleeve):_draw_legacy_sleeve(host,assets[sleeve],arm,tint,27.0 if sleeve=="sleeve_blue" else 20.0)
 _draw_hand_form(host,arm,tint)
func _draw_legacy_sleeve(host:CanvasItem,texture:Texture2D,arm:Dictionary,tint:Color,old_displacement:float)->void:
 # QA-only inverse of the import registration. Both rows use identical
 # normalized artwork and skeleton; only the old misplaced sleeve map returns.
 var size:=Vector2(texture.get_size())
 for row in range(32):
  var top:=float(row)/32.0*size.y;var bottom:=float(row+1)/32.0*size.y
  var uv:=PackedVector2Array([Vector2(0,top/size.y),Vector2(1,top/size.y),Vector2(1,bottom/size.y),Vector2(0,bottom/size.y)])
  var points:=PackedVector2Array()
  for q in uv:points.append(_skin_arm(q*size+Vector2(old_displacement,0),arm))
  _draw_quad(host,texture,points,uv,tint)
func _draw_body_part(host:CanvasItem,texture:Texture2D,rect:Rect2,pose:Dictionary)->void:
 _draw_body_region(host,texture,rect,pose,Rect2(0,0,1,1),false)
func _draw_body_region(host:CanvasItem,texture:Texture2D,rect:Rect2,pose:Dictionary,region:Rect2,garment:bool=true)->void:
 var p:=rect.position+rect.size*region.position
 var e:=rect.position+rect.size*region.end
 var points:=PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)])
 for i in range(4):points[i]=_body(points[i],pose.shift,float(pose.body_angle))
 var uv:=PackedVector2Array([region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)])
 _draw_quad(host,texture,points,uv,Color.WHITE)
