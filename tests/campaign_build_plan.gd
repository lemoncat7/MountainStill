extends RefCounted
## Lawful shared QA plan. Pays real costs and waits actual saved timers.
## No injected resources, levels, equipment, victories, or hidden healing.
const BUILDS := ["sword", "fire", "guard", "control", "support"]
const Beast = preload("res://scripts/beast_presentation.gd")
const HOST_WINDOW_WIDTH := 1200.0

static func measurement_metadata() -> Dictionary:
 var hashes: Dictionary = {}
 # Bind every runtime helper, including choreography, contact feedback and the
 # renderer, plus the actual monster paintings and collision landmarks. A new
 # pose file must invalidate a measured snapshot just as a mechanics edit does.
 _hash_measurement_tree("scripts", hashes)
 _hash_measurement_tree("assets/cultivation/beasts", hashes, true)
 for path in ["tests/campaign_build_plan.gd", "tests/test_encounter_balance.gd",
  "tests/test_encounter_sensitivity.gd"]:
  hashes[path] = FileAccess.get_sha256("res://" + path)
 return {"godot": Engine.get_version_info().string, "window_width": HOST_WINDOW_WIDTH,
  "geometry": "native route artwork and authored monster poses, 88/120 design-unit spacing, shared painted-body contact",
  "source_scope": "all runtime scripts, runtime monster art and JSON, and campaign measurement tests; raw source paintings excluded",
  "source_sha256": hashes}

static func _hash_measurement_tree(directory: String, hashes: Dictionary, skip_raw_sources: bool = false) -> void:
 var files := DirAccess.get_files_at("res://" + directory)
 files.sort()
 for filename in files:
  if filename.begins_with(".") or filename.ends_with(".import") or filename.ends_with(".uid"):
   continue
  var path := directory.path_join(filename)
  hashes[path] = FileAccess.get_sha256("res://" + path)
 var directories := DirAccess.get_directories_at("res://" + directory)
 directories.sort()
 for child in directories:
  if child.begins_with(".") or (skip_raw_sources and child == "sources"):
   continue
  _hash_measurement_tree(directory.path_join(child), hashes, skip_raw_sources)

static func prepare_enemy(definition: Dictionary, route: String, window_width: float = HOST_WINDOW_WIDTH) -> Dictionary:
 # Mirror cultivation.gd _prepare_stage_monster/_begin_duel at the actual
 # route stop: hero at ROUTE_HERO_X, normal foe +88, boss +120 design units.
 # Painted-body geometry requires the route artwork, not just visual_type.
 var enemy := definition.duplicate(true)
 var boss := bool(enemy.get("boss", false))
 enemy.route_id = route
 enemy.engagement_distance = (120.0 if boss else 88.0) * window_width / 1040.0
 var attack_key := route + ("_boss" if boss else "") + "_attack"
 enemy.enemy_front_extent = maxf(24.0, -Beast.visible_bounds(attack_key, 174.0 if boss else 112.0).position.x)
 return enemy

static func row(s, id: String) -> Dictionary:
 for entry in s.technique_rows():
  if str(entry.id) == id:return entry
 return {}

static func study(s, id: String, target: int) -> int:
 if not s.Content.TECHNIQUES.has(id):return 0
 var point:Dictionary=row(s,id)
 if point.is_empty() or s.realm<int(point.unlock_realm):return 0
 var attuned:Dictionary=s.attune_technique(id)
 if not attuned.get('ok',false) and not row(s,id).get('attuned',false):return 0
 var completed:=0
 for attempt in range(8):
  point=row(s,id)
  if int(point.level)>=mini(target,int(point.max_level)):break
  if not point.get('can_upgrade',false):break
  var result:Dictionary=s.upgrade_technique(id)
  if not result.get('ok',false):break
  # Step through the actual game's timer. Quiet cultivation continues normally.
  s.step(float(result.get('duration',0.0))+.001)
  if int(row(s,id).level)<=int(point.level):break
  completed+=1
 return completed

static func choose_heart(s, id: String) -> bool:
 if s.equipped_heart==id:return true
 if int(s.technique_levels.get(id,0))<=0:return false
 var quote:Dictionary=s.quote_heart_switch(id)
 if not quote.get('ok',false):return false
 var result:Dictionary=s.confirm_heart_switch(quote)
 if not result.get('ok',false):return false
 s.step(float(quote.get('duration',0.0))+.001)
 return s.equipped_heart==id

static func configure(s, build: String, chapter: int) -> Dictionary:
 var waits_before:float=s.lifetime_seconds
 # Every path keeps a usable sword form; the fixed first clear really awards it.
 # The fan is not silently granted: it enters a normal first-clear inventory only
 # at the final chapter, so fan QA uses separate clearly labelled fixtures.
 study(s,'breath',2 if chapter>=2 else 1)
 study(s,'mist',mini(6,chapter+2) if build=='sword' else 1)
 var wanted:Array=[]
 match build:
  'fire':wanted=['ember','body','barrier']
  'guard':wanted=['stillness','barrier','body','mending']
  'control':wanted=['frost','body','thunder','barrier']
  'support':wanted=['stillness','mending','body','barrier']
  _:wanted=['body','barrier','frost','thunder']
 for id in wanted:
  var target:=1
  if id in ['ember','stillness','frost','mending','barrier'] and build!='sword':target=mini(3,chapter+1)
  study(s,id,target)
 choose_heart(s,'stillness' if build in ['guard','support'] and int(s.technique_levels.get('stillness',0))>0 else 'breath')
 s.equip_technique('mist','weapon_art')
 if int(s.technique_levels.get('body',0))>0:s.equip_technique('body','passive')
 # Actives are independent of the form and can be offense, control or support.
 for id in s.equipped_actives.duplicate():s.unequip_technique(str(id),'active')
 var priority:Array=[]
 match build:
  'fire':priority=['ember','mist','barrier']
  'guard':priority=['barrier','mending','mist']
  'control':priority=['frost','thunder','mist']
  'support':priority=['mending','barrier','mist']
  _:priority=['mist','thunder','barrier']
 for id in priority:
  if int(s.technique_levels.get(id,0))>0:s.equip_technique(id,'active')
 return {'build':build,'heart':s.equipped_heart,'form':s.equipped_weapon_art,'actives':s.equipped_actives.duplicate(),'passives':s.equipped_passives.duplicate(),'training_seconds':s.lifetime_seconds-waits_before}

static func buy_affordable_meridians(s) -> void:
 for point in s.meridian_rows():
  var current:Dictionary={}
  for candidate in s.meridian_rows():
   if candidate.id==point.id:current=candidate
  if current.get('can_unlock',false):s.unlock_meridian(str(point.id))
