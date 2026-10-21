extends "res://tests/show_basic_modules_revision.gd"
## The normal-speed basic proof plus exact shared geometry at every resolved hit.
## Same isolated fixture and production host/timeline as the original recorder.
const ContactRig=preload('res://scripts/character_sidewalk.gd')
var observed_contact:=''
func _process(delta:float):
 super._process(delta)
 if not is_instance_valid(scene) or scene.encounter_phase!='fight':return
 var event:Dictionary=scene.duel._last_contact
 var id:=str(event.get('contact_id',''))
 if id.is_empty() or id==observed_contact:return
 observed_contact=id
 var current:Dictionary=scene.duel_pose
 print('PHYSICAL_CONTACT '+JSON.stringify({'frame_time':clock,'event':event,'hero':current.get('hero',{}),'enemy':current.get('enemy',{}),'footwork':ContactRig.approach_footwork(current.get('hero',{}))}))
