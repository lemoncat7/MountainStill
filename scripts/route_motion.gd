extends RefCounted
## One screen-space velocity drives landscape, every route prop and the gait.
## Integrate in small bounded steps so low frame rates cannot jump into a fight.
const CRUISE_SPEED := 48.0
const ACCELERATION := 108.0
const BRAKING := 108.0
const STEP := 1.0 / 240.0

static func advance(distance:float, velocity:float, target:float, delta:float, screen_scale:float=1.0)->Dictionary:
	var position:=distance*screen_scale
	var destination:=maxf(distance,target)*screen_scale
	var speed:=maxf(0.0,velocity)
	var time_left:=maxf(0.0,delta)
	while time_left>0.0000001:
		var dt:=minf(STEP,time_left)
		var remaining:=maxf(0.0,destination-position)
		if remaining<0.000001:
			position=destination;speed=0.0;break
		# Reserve one integration step for braking, avoiding a last-frame hard stop.
		var safe_speed:=sqrt(2.0*BRAKING*remaining)
		var desired:=minf(CRUISE_SPEED,maxf(0.0,safe_speed-BRAKING*dt))
		var next_speed:=move_toward(speed,desired,(ACCELERATION if desired>speed else BRAKING)*dt)
		var step:=(speed+next_speed)*0.5*dt
		if step>=remaining:
			position=destination;speed=0.0;break
		position+=step;speed=next_speed;time_left-=dt
		if remaining<0.002 and speed<0.5:
			position=destination;speed=0.0;break
	var arrived:=absf(destination-position)<0.000001
	return {"distance":maxf(distance,target) if arrived else position/maxf(0.001,screen_scale),"velocity":speed,"arrived":arrived}
