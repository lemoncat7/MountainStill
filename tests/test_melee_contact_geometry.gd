extends SceneTree
## The same painted body and actual strike points gate render placement and HP.
const Duel=preload('res://scripts/duel_timeline.gd')
const Rig=preload('res://scripts/character_sidewalk.gd')
const Geometry=preload('res://scripts/melee_contact_geometry.gd')
const Content=preload('res://scripts/cultivation_content.gd')
var checks:=0
var failures:=0
var hits:=0
var whiffs:=0
var min_clearance:=INF
var max_approach_step:=0.0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func hero(style:String,paid:bool=false)->Dictionary:
 var result:={'hp':10000,'max_hp':10000,'attack':11,'defense':1,'combat_qi_regen':0.0,'battle_resources':{'qi':0.0},'heart_method':{},'weapon_art':{},'active_skills':[],'passive_methods':[],'weapon_skill':{}}
 if paid:
  result.combat_qi_max=400.;result.battle_resources.qi=400.
  for id in ['mist' if style=='sword' else 'petal','ember','barrier','mending']:
   var skill:Dictionary=Content.TECHNIQUES[id].duplicate(true);skill.id=id;skill.active=true;skill.power_scale=1.;result.active_skills.append(skill)
  if style!='unarmed':result.weapon_skill={'id':'weapon_'+style+('_pierce' if style=='sword' else '_return'),'active':true,'qi_cost':1.,'cooldown':1.}
 return result
func enemy(route:String,boss:bool,width:float)->Dictionary:
 return {'hp':10000,'max_hp':10000,'attack':2,'defense':1,'boss':boss,'route_id':route,'engagement_distance':(120.0 if boss else 88.0)*width/1040.,'dodge_chance':0.0,'guard_chance':0.0}
func _initialize():
 for route in ['bamboo_pass','creek_bridge','cloud_slope','ember_ruins','moon_marsh','summit_gate']:
  for boss in [false,true]:
   for width in [800.,1200.,1600.]:
    for style in ['sword','fan','unarmed']:
     var d:=Duel.new();var definition:=enemy(route,boss,width)
     d.start(hero(style),definition,'mist',style,377)
     var previous:=0.0
     for frame in range(360):
      for e in d.advance(1./60.):
       if e.type!='contact' or e.actor!='hero':continue
       check(e.has('melee_contact'),'all physical moves carry exact contact geometry')
       var g:Dictionary=e.melee_contact
       check(e.damage==0 or (g.contact and g.vertical_valid),'positive melee HP delta requires a real painted-body contact '+route+'/'+style)
       check(e.damage==e.pre_hp-e.post_hp,'contact event equals actual HP change')
       if e.resolution=='whiff':
        whiffs+=1;check(e.damage==0 and e.get('poise_damage',0)==0,'miss creates no HP or posture damage')
       elif e.damage>0:hits+=1
      var p:=d.pose();var step:Dictionary=Rig.approach_footwork(p.hero)
      var amount:=absf(float(step.root)-previous);max_approach_step=maxf(max_approach_step,amount);previous=float(step.root)
      check(amount<4.0,'approach remains continuous at 60Hz '+route+'/'+style)
      var body:=Rig.sample_pose(p.hero)
      check(body.near_leg.planted or body.far_leg.planted,'weight transfer preserves a grounded sole')
      if p.enemy.has('body_clearance'):
       min_clearance=minf(min_clearance,p.enemy.body_clearance)
       check(p.enemy.body_clearance>=2.99,'moving beast never crosses hero body plane')
      if route in ['cloud_slope','moon_marsh'] and p.enemy.combat_phase in ['strike','contact']:
       check(p.enemy.visual_offset.y<0.0,'airborne target keeps its genuine vertical displacement')
 _test_paid_and_finish()
 _test_host_whiff()
func _test_paid_and_finish():
 for style in ['sword','fan']:
  var kinds:={}
  for support in [false,true]:
   var stats:=hero(style,true)
   if support:
    stats.active_skills=stats.active_skills.slice(2);stats.hp=7000
   var d:=Duel.new();d.start(stats,enemy('bamboo_pass',true,1200),'mist',style,377)
   var previous:=0.0
   for i in range(3600):
    for e in d.advance(1./120.):
     if e.type=='contact' and e.actor=='hero':
      kinds[e.action_kind]=true
      if Geometry.is_melee(e):check(e.damage==0 or e.melee_contact.contact,'paid art and innate weapon require physical contact')
    var root:=float(Rig.approach_footwork(d.pose().hero).root)
    check(absf(root-previous)<3.0,'basic to spell/support/weapon transition never resets the close stance');previous=root
  check(kinds.has('weapon_art') and kinds.has('weapon') and kinds.has('spell') and kinds.has('defense') and kinds.has('utility'),'paid and support transitions were actually exercised '+str(kinds))
 var d:=Duel.new();var target:=enemy('bamboo_pass',true,1200);target.hp=10
 d.start(hero('unarmed'),target,'mist','unarmed',377)
 var previous:=0.0
 for i in range(1200):
  d.advance(1./120.);var root:=float(Rig.approach_footwork(d.pose().hero).root)
  check(absf(root-previous)<3.0,'finishing disengage is continuous');previous=root
  if d.finished:break
 check(d.finished and absf(previous)<.001,'finishing reaches base stance before pickup')
func _test_host_whiff():
 var scene=load('res://main.tscn').instantiate();scene.state.save_path='user://melee_geometry_isolated.json';root.add_child(scene)
 await process_frame
 scene.set_process(false);scene.encounter_active=true;scene.encounter_phase='fight';scene.meditation_amount=0.;scene.world_route='bamboo_pass';scene.route_boss=true;scene.character_x=390.;scene.character_y=230.
 var target:=enemy('bamboo_pass',true,1200);target.engagement_distance=900.
 scene.duel.start(hero('unarmed'),target,'mist','unarmed',377);scene.duel_pose=scene.duel.pose()
 var first:float=scene.duel_pose.contact_times[0]
 scene._update_encounter(first)
 check(scene.duel_resolution=='whiff','host receives exact empty-swing result')
 check(scene.enemy_flash==0.0 and scene.combat_number_time==0.0 and scene.combat_impacts.filter(func(impact):return str(impact.target)=='enemy').is_empty(),'whiff emits no flash, damage popup or impact')
 check(not scene.duel._counter_ready,'empty swing does not earn a defensive counter')
 scene.queue_free();await process_frame
 print('Melee geometry: %d checks, %d failures; real hits=%d whiffs=%d minimum body clearance=%.3f max 60Hz approach step=%.3f' % [checks,failures,hits,whiffs,min_clearance,max_approach_step])
 quit(1 if failures else 0)
