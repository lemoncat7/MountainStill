extends SceneTree
var scene
func _initialize():call_deferred('start')
func snap(name:String):
 await create_timer(1.1).timeout
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png('user://'+name+'.png')
func start():
 scene=load('res://main.tscn').instantiate();root.add_child(scene)
 await process_frame
 scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
 scene.get_window().transparent_bg=false;scene.strip=true;scene.desktop.transparent_enabled=true
 RenderingServer.set_default_clear_color(Color('#e8e7df'))
 scene.set_meta('ink_journal_tab','guide');scene._toggle_drawer('practice')
 await snap('qa-guide')
 scene.set_meta('ink_journal_tab','practice');scene._refresh_drawer()
 await snap('qa-practice')
 scene.wardrobe_tab='expedition';scene._toggle_drawer('wardrobe')
 await snap('qa-chapter1')
 scene.set_meta('ink_stage_page',1);scene.set_meta('ink_stage_id','summit_gate');scene._refresh_drawer()
 await snap('qa-chapter6-locked')
 scene.state.realm=15
 for id in scene.state.Content.CHAPTER_ORDER:scene.state.stage_clears[id]=1
 scene.set_meta('ink_journal_tab','ending');scene._toggle_drawer('practice')
 await snap('qa-ending-ready')
 scene.buttons.ending_action.pressed.emit()
 await snap('qa-ending-complete')
 scene.queue_free();await process_frame;await process_frame;quit()
