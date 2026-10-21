extends "res://tests/show_readable_combat_demo.gd"
## Explicit QA comparison: same earned checkpoint, stats, opponent and seed.
## Only effective speed is set to the labeled value before any combat advance.
var comparison_speed:=100.0
func start():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--speed="):comparison_speed=float(arg.trim_prefix("--speed="))
 super.start()
func begin_bout():
 super.begin_bout()
 if not is_instance_valid(scene) or finished:return
 var hero:Dictionary=scene.duel._hero.duplicate(true)
 var enemy:Dictionary=scene.duel._enemy.duplicate(true)
 hero.speed=comparison_speed;enemy.speed=comparison_speed
 scene.duel.start(hero,enemy,scene.state.technique,scene._attack_style(),scene.encounter_run_id*1337+scene.encounter_index*79+17)
 scene.duel_pose=scene.duel.pose();scene.side_motion.merge(scene.duel_pose.hero,true)
 bouts[-1].comparison_speed=comparison_speed;bouts[-1].hero_input=hero;bouts[-1].enemy_input=enemy
 banner.text="速度对照 · 双方速度 %d · 正常原生播放 / 引擎时钟 1×"%comparison_speed
 details.text="同一存档、对手、装备和随机种子，仅设定本段双方速度。动作与实际命中同步；技能冷却不加速。"
func _process(delta:float)->bool:
 var result:=super._process(delta)
 if not finished and clock>=8.0:finish()
 return result
