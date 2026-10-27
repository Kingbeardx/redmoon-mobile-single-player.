extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func touch(button: Button) -> void:
	await process_frame;await process_frame
	for down in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=2;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;w.create_character("Shadow",3,"user://stances-ui.json");w.level=300;w.honor=200;w.stats["spirit"]=300;w.mana=w.max_mana();w.hp=w.max_hp();w.skills.reset();w.skills.assign(0,34);scene._update_ui()
	await touch(scene.skill_button);check(not w.skills.active("hide").is_empty(),"touch slot casts Hide")
	scene._update_ui();check(scene.skill_button.caption.text=="END HIDE" and scene.buff_label.text.contains("Hide"),"HUD makes active Hide and toggle action clear")
	w.mana=0;w.attack_cooldown=0;w.skills.cooldowns.clear();scene._update_ui()
	check(not scene.skill_button.disabled and w.skills.cost(34)==0,"zero MP does not disable ending Hide")
	await touch(scene.skill_button);check(w.skills.active("hide").is_empty(),"actual zero-MP touch ends Hide")
	w.character_id=6;w.level=350;w.honor=350;w.mana=w.max_mana();w.skills.reset();w.skills.assign(0,65);w.attack_cooldown=0;scene._update_ui()
	await touch(scene.skill_button);check(not w.skills.active("psychic_reflect").is_empty(),"Red Halo casts from touch hotbar")
	scene._update_ui();check(scene.buff_label.text.contains("Red Halo"),"reflection stance appears on readable HUD")
	scene.game_ui.show_effects();await process_frame;await process_frame;check(scene.game_ui.effect_text.text.contains("Red Halo"),"reflection timer appears in active-effects menu")
	scene.game_ui.close();scene.game_ui.selected_skill=65;scene.game_ui.show_skills();await process_frame;await process_frame
	check(scene.game_ui.skill_buttons.has(65) and not scene.game_ui.skill_cast_button.disabled,"class skill menu admits Red Halo with original requirements")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v14-stances.png")
	scene.game_ui.close();w.character_id=1;w.level=400;w.honor=-400;w.stats["spirit"]=15000;w.mana=w.max_mana();w.skills.reset();w.skills.assign(2,312);w.attack_cooldown=0;scene._update_ui()
	await touch(scene.extra_skill_buttons[1]);check(is_equal_approx(w.skills.basic_attack_delay(),.225),"third touch slot activates Psychic Boost attack rate")
	scene._update_ui();check(scene.buff_label.text.contains("Psychic Boost"),"speed stance displays its duration")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute("user://stances-ui.json"+suffix)
	scene.queue_free();await process_frame;print("STANCES UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
