extends SceneTree
## Native animation proof: 12 seconds, 48 px/s right then left.
## Optional movie: --write-movie builds/full-v1/sidewalk-live.avi --fixed-fps 60
## Set SIDEWALK_LIVE=1 to keep looping until the native window is closed.
const Walk=preload("res://scripts/character_sidewalk.gd")
class LiveCanvas extends Node2D:
	var rig=Walk.new()
	func _ready()->void:
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var time:=0.0
	var x:=190.0
	var motion:Dictionary={"facing":1.0,"blend":0.0}
	var completed:=false
	func _process(delta:float)->void:
		time+=delta
		var t:=fposmod(time,12.0)
		var velocity:=48.0 if t<5.5 else (0.0 if t<6.0 or t>=11.5 else -48.0)
		x+=velocity*delta
		motion=rig.update_motion(delta,velocity,1.35)
		queue_redraw()
		if time>=12.0 and OS.get_environment("SIDEWALK_LIVE")!="1":
			get_tree().quit()
	func _draw()->void:
		draw_rect(Rect2(0,0,800,320),Color("f1ecdf"))
		var font=ThemeDB.fallback_font
		draw_string(font,Vector2(24,30),"SIDE WALK  |  48 px/s  |  Original bare base + white shorts",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("294c49"))
		var state:="Right" if motion.get("velocity",0.0)>0.5 else ("Left" if motion.get("velocity",0.0)<-0.5 else "Settle / turn")
		draw_string(font,Vector2(24,56),"%.1f s  /  %s"%[time,state],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("526660"))
		draw_line(Vector2(24,258),Vector2(776,258),Color("8e9d91"),2.0)
		for tick in range(32):
			var px:=float(24+tick*24)
			draw_line(Vector2(px,258),Vector2(px,264),Color("8e9d91"))
			if tick%4==0:draw_string(font,Vector2(px-8,280),str(int(px)),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("6d7d73"))
		var feet:=Vector2(x,258)
		rig.draw_avatar_layers(self,feet,{},{},motion,1.35)
		var pose=Walk.sample_pose(motion)
		for key in ["far_leg","near_leg"]:
			var leg:Dictionary=pose[key]
			if leg.planted:
				var anchor:=feet+Vector2(float(leg.ankle.x)*float(pose.facing),0)*Walk.PIXEL_SCALE*1.35
				draw_circle(anchor+Vector2(0,8),2.2,Color("b17b41"))
		draw_string(font,Vector2(24,307),"Ground ticks stay fixed. Gold dots mark planted ankle contacts. No equipped gear in this proof.",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("526660"))
func _initialize()->void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(800,320)
	root.add_child(LiveCanvas.new())
	_resize.call_deferred()
func _resize()->void:
	await process_frame
	root.size=Vector2i(800,320)
