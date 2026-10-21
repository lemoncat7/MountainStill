extends Button
## A scene object becomes the navigation. Only proximity/focus reveals its seal.
const FONT=preload("res://assets/fonts/MaShanZheng-Regular.ttf")
var caption=""
var wash=0.0
var seal=false
func _ready():
	flat=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for n in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(n,StyleBoxEmpty.new())
	for n in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:add_theme_color_override(n,Color.TRANSPARENT)
func _process(delta):
	wash=move_toward(wash,1.0 if is_hovered() or has_focus() else 0.0,delta*6)
	queue_redraw()
func _draw():
	var a=0.62+wash*.38 if seal else wash
	if a<.01:return
	var p=Vector2(size.x-30,8)
	if seal:p=Vector2(1,1)
	var h=26 if seal else 55
	var points=PackedVector2Array([p+Vector2(1,0),p+Vector2(28,1),p+Vector2(27,h),p+Vector2(0,h-1)])
	draw_colored_polygon(points,Color(.96,.94,.86,a*.90))
	for j in range(3):
		draw_line(p+Vector2(2+j*.4,2),p+Vector2(25,2+j*.5),Color(.35,.30,.24,a*.15),.55,true)
	if seal:
		draw_string(FONT,p+Vector2(7,20),"山",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(.57,.20,.16,a))
	else:
		for i in range(caption.length()):draw_string(FONT,p+Vector2(6,20+i*18),caption[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(.19,.23,.22,a))
		draw_rect(Rect2(p+Vector2(11,h-8),Vector2(5,4)),Color(.65,.22,.16,a*.85))
