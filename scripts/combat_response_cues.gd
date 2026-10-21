extends RefCounted
## Pure outcome-to-presentation adapter. No rules, clocks, weapon branches,
## provider lookups, RNG or mutable caches live here. All contact marks retain
## the real contact ID and earned counters retain their defensive source ID.
const DEFLECT_SECONDS := 0.27
const COUNTER_COLOR := Color("b18b45")
const WARD_COLOR := Color("97a975")

static func contact_cue(event: Dictionary) -> Dictionary:
 var resolution := str(event.get("resolution", ""))
 var contact_id := str(event.get("contact_id", ""))
 if contact_id.is_empty() or resolution in ["whiff", "dodge", "support", "heal", "shield"]: return {}
 var result := {"contact_id":contact_id,"counter_source":str(event.get("counter_source","")),"kind":""}
 if resolution == "guard" and not bool(event.get("poise_broken",false)):
  result.kind = "deflection"
  result.earned_counter = bool(event.get("counter_earned",false))
 elif bool(event.get("counter",false)) and not result.counter_source.is_empty() and resolution == "hit" and int(event.get("damage",0)) > 0:
  result.kind = "counter_hit"
 result.shield_absorbed = maxi(0,int(event.get("shield_absorbed",0)))
 result.shield_depleted = int(result.shield_absorbed)>0 and int(event.get("shield_after",-1))==0
 return result if not str(result.kind).is_empty() or int(result.shield_absorbed)>0 else {}

## Bounded anticipation overlay. The authored strike endpoint remains EXACTLY
## unchanged, including every multi-hit contact and all attack geometry samples.
static func counter_load(motion: Dictionary) -> float:
 if not bool(motion.get("counter",false)) or str(motion.get("counter_source","")).is_empty(): return 0.0
 if int(motion.get("strike_index",0))>0:return 0.0
 var phase := str(motion.get("combat_phase",""))
 var p := clampf(float(motion.get("phase_progress",0.0)),0.0,1.0)
 if phase == "windup": return smoothstep(0.0,0.42,p)
 if phase == "strike": return 1.0-smoothstep(0.0,0.68,p)
 return 0.0

static func guard_release(motion: Dictionary) -> float:
 if str(motion.get("defense_action","")) != "guard" or str(motion.get("contact_id","")).is_empty(): return 0.0
 if bool(motion.get("guard_broken",false)):return 0.0
 var age:=float(motion.get("reaction_age",-1.0))
 if age<0.0 or age>=DEFLECT_SECONDS:return 0.0
 return smoothstep(0.0,0.075,age)*(1.0-smoothstep(0.11,DEFLECT_SECONDS,age))

## Attacker follow-through is redirected only AFTER a real blocked contact.
## This is an extra rigid render transform; it never changes source-pose choice,
## collision geometry, action phase, interruption, contact timing or root spacing.
static func deflection_transform(motion: Dictionary) -> Dictionary:
 var age:=float(motion.get("deflection_age",-1.0))
 var duration:=float(motion.get("deflection_duration",DEFLECT_SECONDS))
 if age<0.0 or age>=duration or str(motion.get("deflected_contact_id","")).is_empty():return {"offset":Vector2.ZERO,"rotation":0.0,"amount":0.0}
 var q:=age/maxf(.001,duration)
 var amount:=smoothstep(0.0,0.28,q)*(1.0-smoothstep(0.43,1.0,q))
 return {"offset":Vector2(4.0,-1.0)*amount,"rotation":0.105*amount,"amount":amount}

static func barrier_status(state: Dictionary) -> String:
 var shield:=maxi(0,int(state.get("shield",0)))
 var seconds:=maxf(0.0,float(state.get("shield_remaining",0.0)))
 return "护元 %d · %.1fs"%[shield,seconds] if shield>0 and seconds>0.0 else ""

## A transparent protective contour with separated, softly lit rim segments.
## The body remains unobscured. Only a real active shield / cast produces it;
## contact absorption/depletion is read from the host's actual impact records.
static func barrier_marks(state: Dictionary,cast_amount: float=0.0) -> Array:
 var shield:=int(state.get("shield",0))
 var remaining:=maxf(0.0,float(state.get("shield_remaining",0.0)))
 var cast:=clampf(cast_amount,0.0,1.0)
 if (shield<=0 or remaining<=0.0) and cast<=0.0:return []
 var fade:=minf(1.0,remaining/.4) if shield>0 else 0.0
 var alpha:=maxf(.34*fade,.62*cast)
 var marks:Array=[]
 for half in range(2):
  var points:=PackedVector2Array()
  for j in range(23):
   var angle:float=(-1.38+float(j)/22.0*2.76)+PI*half
   points.append(Vector2(1,-38)+Vector2(cos(angle)*23,sin(angle)*39))
  marks.append({"points":points,"alpha":alpha})
 return marks

static func barrier_feedback(impacts:Array) -> Dictionary:
 var result:Dictionary={}
 for record in impacts:
  var cue:Dictionary=record.get("profile",{}).get("response_cue",{})
  var age:=float(record.get("age",1.0))
  if int(cue.get("shield_absorbed",0))>0 and age<.32 and (result.is_empty() or age<float(result.age)):
   result={"age":age,"depleted":bool(cue.get("shield_depleted",false))}
 return result

static func draw_barrier(canvas: CanvasItem,body_feet:Vector2,state: Dictionary,cast_amount:float=0.0,impacts:Array=[]) -> void:
 var feedback:=barrier_feedback(impacts)
 var marks:=barrier_marks(state,cast_amount)
 var broken:=not feedback.is_empty() and bool(feedback.depleted)
 if broken and marks.is_empty():marks=barrier_marks({"shield":1,"shield_remaining":1.0})
 var pulse:=0.0 if feedback.is_empty() else 1.0-smoothstep(0.0,.24,float(feedback.age))
 for mark in marks:
  var points:=PackedVector2Array()
  var dissolve:=float(feedback.age)/.32 if broken else 0.0
  for point in mark.points:
   points.append(body_feet+point+(point-Vector2(1,-38))*.16*dissolve)
  var alpha:=float(mark.alpha)*(1.0-dissolve)+pulse*.16
  if broken:
   # Small separated remnants drift away after the actual last absorption.
   for i in range(0,points.size()-2,5):
    canvas.draw_polyline(PackedVector2Array([points[i],points[i+1],points[i+2]]),Color(WARD_COLOR,alpha),1.0,true)
  else:
   # A luminous edge, without a filled white surface. The original narrow
   # body-sized contour remains transparent and open at its upper/lower tips.
   canvas.draw_polyline(points,Color("a4edcf",alpha*.24),6.5,true)
   canvas.draw_polyline(points,Color("b8f6d7",alpha*.75),2.6,true)
   canvas.draw_polyline(points,Color("d2ffe8",minf(.86,alpha*1.65)),1.15,true)
   canvas.draw_polyline(points,Color("efffe4",alpha*.90),.45,true)
 # A small chest rune makes the sustaining technique legible inside the field.
 if not marks.is_empty() and not broken:
  var point:=body_feet+Vector2(7,-34)
  canvas.draw_polyline(PackedVector2Array([point+Vector2(-3,-5),point+Vector2(2,-2),point+Vector2(-1,3),point+Vector2(3,5)]),Color(WARD_COLOR,.37+pulse*.30),1.1,true)

## Deflection is a short incoming line that visibly changes direction, plus
## discrete flecks, rather than another round shield. Punish marks only exist
## on a counter that actually hit; an evaded/blocked counter gets no gold burst.
static func draw_contact(canvas:CanvasItem,cue:Dictionary,point:Vector2,age:float,scale_value:float=1.0) -> void:
 if cue.is_empty() or age<0.0:return
 var kind:=str(cue.get("kind",""))
 if kind=="deflection" and age<.30:
  var p:=clampf(age/.30,0.0,1.0)
  var fade:=1.0-smoothstep(.30,1.0,p)
  var tip:=point+Vector2(8+12*smoothstep(0.0,.7,p),-5-12*smoothstep(0.0,.7,p))*scale_value
  var silver:=Color("9eafa7")
  canvas.draw_polyline(PackedVector2Array([point+Vector2(9,3)*scale_value,point,tip]),Color(silver,fade*.86),1.4*scale_value,true)
  for i in range(3):
   var end:=point+Vector2(7+i*4,-7-i*3)*scale_value*(.45+p)
   canvas.draw_line(end,end+Vector2(3,-2)*scale_value,Color("e6dfb8",fade*.9),1.25*scale_value,true)
 elif kind=="counter_hit" and age<.30:
  var fade:=1.0-smoothstep(.025,.30,age)
  var travel:=smoothstep(0.0,.18,age)
  for sign_value in [-1.0,1.0]:
   var axis:=Vector2(1,sign_value*.62).normalized()
   var start:=point-axis*(4+travel*4)*scale_value
   var finish:=point+axis*(8+travel*9)*scale_value
   canvas.draw_line(start,finish,Color(COUNTER_COLOR,fade*.9),1.7*scale_value,true)
  if age<.10:canvas.draw_circle(point,2.3*scale_value,Color("fff0cb",fade*.95))
 if int(cue.get("shield_absorbed",0))>0 and age<.22:
  var fade:=1.0-smoothstep(0.0,.22,age)
  var p:=point+Vector2(0,-2)*scale_value
  canvas.draw_polyline(PackedVector2Array([p+Vector2(-4,-7)*scale_value,p+Vector2(4,-3)*scale_value,p+Vector2(1,2)*scale_value,p+Vector2(5,7)*scale_value]),Color(WARD_COLOR,fade),1.9*scale_value,true)
