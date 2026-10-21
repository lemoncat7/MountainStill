extends "res://tests/show_looting_crafting_demo.gd"
## Short production-host excerpt. Same legally earned checkpoint, original
## HP/attack/defense/qi, actual event resolution, 1x native engine playback.
func _process(delta:float)->bool:
 var result:=super._process(delta)
 if not finished and clock>=34.0:finish()
 return result
func begin_bout():
 super.begin_bout()
 if is_instance_valid(banner):
  banner.text="原生实战 · 1×速度 · 架剑格挡 / 双向受力 / 真实反击"
  details.text="真实所得首领存档；气血、攻击、命中与技能规则未改。另附无特效姿态检查。"
