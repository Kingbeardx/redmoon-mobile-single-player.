extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;w.create_character("Lunarena",7,"user://protection-ui.json");w.level=100;w.stats["spirit"]=300;w.mana=w.max_mana();w.skills.reset();w.skills.assign(0,73)
	w.skills.apply_ailment("freeze",3);scene._update_ui()
	check(scene.buff_label.text.contains("FREEZE"),"harmful effect is readable on HUD")
	scene.game_ui.show_effects();await process_frame;await process_frame
	check(scene.game_ui.effect_text.text.contains("FREEZE"),"effects panel describes current impairment")
	w.skills.tick(3.1);scene.game_ui.refresh_effects();check(scene.game_ui.effect_text.text=="No active effects.","effects panel updates expired status")
	scene.game_ui.close();w.skills.control_grace=0;w.skills.apply_ailment("freeze",3);scene._update_ui()
	for down in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=2;e.pressed=down;e.position=scene.skill_button.get_global_rect().get_center();root.push_input(e,true)
	check(w.skills.ailments.is_empty() and w.mana==250,"actual touch cleanses frozen character using Sweet Water")
	scene._update_ui();check(not scene.buff_label.text.contains("FREEZE"),"HUD removes cleansed status")
	scene.game_ui.selected_skill=73;scene.game_ui.show_skills();await process_frame;await process_frame
	check(scene.game_ui.skill_buttons.has(73) and not scene.game_ui.skill_assign_buttons[0].disabled,"Lunarena original cleansing skill appears in correct class list")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v12-protection.png")
	scene.game_ui.close();w.skills.apply_ailment("blind",6);scene.game_ui.show_effects();await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v12-effects.png")
	var first: Texture2D=scene.frontend._hero_texture(6);var second: Texture2D=scene.frontend._hero_texture(7)
	check(first!=null and second!=null and first.get_image().get_data()!=second.get_image().get_data(),"both mapped heroine portraits load as distinct originals")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute("user://protection-ui.json"+suffix)
	scene.queue_free();await process_frame;print("PROTECTION UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
