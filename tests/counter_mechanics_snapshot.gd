extends SceneTree
const Duel=preload("res://scripts/duel_timeline.gd")
func _initialize():
 var result:Dictionary={}
 for route in ["bamboo_pass","cloud_slope","ember_ruins"]:
  for style in ["sword","fan","unarmed"]:
   var d=Duel.new()
   d.start({"hp":9999,"max_hp":9999,"attack":10,"defense":2},{"hp":9999,"max_hp":9999,"attack":8,"defense":1,"boss":true,"route_id":route},"stillness",style,17)
   var rows:Array=[]
   for event in d.advance(45.0):
    var row:Dictionary={}
    for key in ["type","actor","move","time","action_id","contact_id","resolution","damage","hero_hp","enemy_hp","counter","counter_kind","counter_source","poise_broken","qi","qi_cost"]:
     if event.has(key):row[key]=event[key]
    if event.type=="contact":row.erase("counter_source")
    rows.append(row)
   result[route+"/"+style]=rows
 var path:String=OS.get_cmdline_user_args()[0]
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
 print("MECHANICS_SNAPSHOT "+path);quit()
