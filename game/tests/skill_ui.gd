extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func press(button: Button) -> void:
	await process_frame;await process_frame
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame;await process_frame
func touch(button: Button) -> void:
	for down in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=2;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;var system=w.skills
	w.create_character("Skill Test",1,"user://skill-ui.json");scene._update_ui();scene.game_ui.show_skills();await process_frame;await process_frame
	check(scene.game_ui.skill_buttons.size()==17,"Azlar original list plus training alternative shown")
	check(scene.game_ui.skill_buttons.has(11) and scene.game_ui.skill_buttons.has(12),"class-specific original skill names listed")
	check(scene.game_ui.skill_cast_button.disabled==false,"available skill can be selected")
	await press(scene.game_ui.skill_buttons[12]);check(scene.game_ui.selected_skill==12 and scene.game_ui.skill_cast_button.disabled,"locked original skill shows disabled cast")
	check(scene.game_ui.skill_assign_buttons.all(func(b:Button)->bool:return b.disabled),"locked skill cannot be bound through UI")
	await press(scene.game_ui.skill_buttons[11]);await press(scene.game_ui.skill_assign_buttons[2]);check(system.slots[2]==11,"real GUI press assigns original spell to slot three")
	scene.game_ui.close();scene._update_ui();check(scene.extra_skill_buttons.size()==2,"three skill touch slots present")
	w.attack_cooldown=0;system.cooldowns.clear();w.mana=50;w.enemies=[{"monster_id":5,"x":w.player.x,"y":w.player.y,"hp":100,"alive":true}];scene._update_ui()
	await touch(scene.extra_skill_buttons[1]);check(w.mana==47 and w.enemies[0]["hp"]==82,"third touch slot casts assigned Psychic Shock")
	w.attack_cooldown=0;system.cooldowns.clear();scene._update_ui();await touch(scene.skill_button);check(scene.game_ui.page=="skills" and scene.game_ui.panel.visible,"empty primary slot opens skill menu")
	scene.game_ui.close();system.assign(0,11);scene._update_ui();var before: int=w.mana
	var key:=InputEventKey.new();key.physical_keycode=KEY_1;key.pressed=true;root.push_input(key,true)
	check(w.mana==before-3,"keyboard one casts first slot")
	w.character_id=0;w.level=50;system.reset();system.ensure_slots();scene.game_ui.selected_skill=3;scene.game_ui.show_skills();await process_frame;await process_frame
	check(not scene.game_ui.skill_cast_button.disabled,"Soul Sphere becomes available at original level fifty")
	check(scene.game_ui.skill_texture(3)!=null,"original skill icon loads")
	check(scene.game_ui.panel.get_global_rect().end.x<=scene.get_viewport_rect().size.x,"skill menu fits screen width")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v10-skills.png")
	scene.game_ui.close();w.character_id=1;w.level=1;system.reset();system.ensure_slots();system.assign(2,11);scene._update_ui();w.enemies=[];w.message="Skills unlock at their original levels · BAG → SKILLS";scene._update_ui()
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1600,720);await process_frame;await process_frame;scene._layout();scene.queue_redraw();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v10-hotbar.png")
	check(scene.extra_skill_buttons.all(func(b:Button)->bool:return scene.get_viewport_rect().encloses(b.get_global_rect())),"extra action slots fit expanded mobile viewport")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute("user://skill-ui.json"+suffix)
	scene.queue_free();await process_frame;print("SKILL UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
