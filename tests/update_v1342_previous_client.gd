extends SceneTree
const Policy=preload("res://scripts/update_policy.gd")
const Store=preload("res://scripts/update_store.gd")
const Bootstrap=preload("res://scripts/update_bootstrap.gd")
var checks:=0
func expect(ok:bool,label:String)->void:
 checks+=1
 if not ok:push_error(label);quit(1);assert(false,label)
func _initialize()->void:_run.call_deferred()
func _run()->void:
 var args:=OS.get_cmdline_user_args()
 var folder:=args[0];var platform:=args[1]
 expect(Store.BUILTIN_VERSION=="1.3.41","actual previous-client bootstrap")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("MountainStill-update.json")))
 expect(manifest.version=="1.3.42","actual candidate manifest")
 var release={"tag_name":"v1.3.42","draft":false,"prerelease":false,"assets":[]}
 for target in ["windows","macos"]:
  var spec:Dictionary=manifest.packages[target]
  release.assets.append({"name":spec.asset,"state":"uploaded","size":spec.size,"digest":"sha256:"+spec.sha256,"browser_download_url":Policy.REPO+"/releases/download/v1.3.42/"+spec.asset})
 for channel in ["stable","testing"]:
  expect(Policy.select_release([release],"1.3.41",channel)==release,"previous client selects complete stable on "+channel)
  var draft:Dictionary=release.duplicate(true);draft.draft=true
  expect(Policy.select_release([draft],"1.3.41",channel).is_empty(),"private incomplete candidate invisible on "+channel)
  for target in ["windows","macos"]:
   var validated:Dictionary=Policy.validate_manifest(manifest,release,target)
   expect(not validated.is_empty(),"previous client accepts platform manifest "+channel+target)
   expect(FileAccess.get_sha256(folder.path_join(validated.asset))==validated.sha256,"actual PCK digest "+target)
 var store:=Store.new();store.platform=platform
 var record:Dictionary=manifest.packages[platform].duplicate()
 for key in ["schema","version","engine","bootstrap","save_schema"]:record[key]=manifest[key]
 record.platform=platform;record.path="user://updates/"+record.sha256+".pck"
 DirAccess.make_dir_recursive_absolute("user://updates")
 expect(DirAccess.copy_absolute(folder.path_join(record.asset),record.path)==OK,"stage candidate PCK")
 expect(store.validate(record),"previous namespace size hash guard")
 expect(store._write("pending.json",record) and store.activate_pending(),"previous client activates new pack")
 var boot:=Bootstrap.new();boot.store=store;root.add_child(boot)
 for i in range(120):await process_frame
 expect(root.get_meta("update_gameplay_ready",false),"actual new gameplay ready")
 expect(store.current_version()=="1.3.42" and store.error.is_empty(),"new version active")
 expect(not FileAccess.file_exists("user://updates/booting.json"),"health committed")
 print("PREVIOUS_CLIENT_V1342_PASS ",platform," checks=",checks)
 quit()
