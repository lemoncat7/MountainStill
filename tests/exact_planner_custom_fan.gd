extends "res://scripts/combat_modules/weapon_fan.gd"
## External-test fixture: exact subclass identity must disable pruning.
var geometry_calls:=0
var pose_calls:=0
func geometry_points(motion:Dictionary,rig_pose:Dictionary,grip:Dictionary)->PackedVector2Array:
 geometry_calls+=1
 return super.geometry_points(motion,rig_pose,grip)
func pose_track(motion:Dictionary,g:float,e:float,stance:float)->Dictionary:
 pose_calls+=1
 return super.pose_track(motion,g,e,stance)
