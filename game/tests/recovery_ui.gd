extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func touch_at(point: Vector2) -> void:
	for down in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=2;e.pressed=down;e.position=point;root.push_input(e,true)
	await process_frame;await process_frame
func touch(button: Button) -> void:await touch_at(button.get_global_rect().get_center())
func click(button: Button) -> void:
	# Ordinary modal buttons use Android's primary-finger mouse emulation path.
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame;await process_frame
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;w.create_character("Recovery",1,"user://recovery-ui.json");scene._update_ui();await process_frame
	check(w.skills.slots[2]==101 and scene.extra_skill_buttons[1].disabled,"new character has original DP special bound, gated by meter")
	check(scene.dp_text.text=="DP 0%" and scene.run_button.text.contains("SP 100%"),"large HUD exposes both new resource states")
	await touch(scene.run_button);check(w.running and scene.run_button.text.begins_with("RUN"),"actual touch toggles running")
	await touch(scene.run_button);check(not w.running,"second touch returns to walking")
	w.danger=w.max_danger();scene._update_ui();check(scene.dp_text.text.contains("SPECIAL READY") and not scene.extra_skill_buttons[1].disabled,"full danger meter clearly enables special action")
	w.enemies=[{"monster_id":5,"name":"Practice","hp":10000,"max_hp":10000,"alive":true,"x":w.player.x+.5,"y":w.player.y,"cooldown":100.0}];w.attack_cooldown=0
	await touch(scene.extra_skill_buttons[1]);check(w.danger==0 and w.enemies[0]["hp"]==9963,"actual third-slot touch executes original area DP attack")
	scene._update_ui();check(scene.dp_text.text=="DP 0%","consumed DP updates HUD immediately")
	scene.game_ui.selected_item="5:93";scene.game_ui.show_bag();await process_frame;await process_frame
	check(scene.game_ui.item_action.text=="READ MAP" and not scene.game_ui.item_action.disabled,"starting Street 1 map has a usable inventory action")
	await click(scene.game_ui.item_action);check(scene.game_ui.page=="map" and w.inventory["5:93"]==1,"map GUI opens area preview without consuming item")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v15-area-map.png")
	scene.game_ui.close();w.character_id=6;w.level=350;w.honor=350;w.stats["spirit"]=300;w.mana=w.max_mana();w.skills.reset();w.skills.assign(0,64);w.attack_cooldown=0;w.enemies=[]
	w.player=w.find_start([9,12]);scene._update_ui();scene.queue_redraw();await process_frame;await process_frame
	await touch(scene.skill_button);check(scene.aiming_skill==64,"Warp touch enters explicit ground targeting")
	await touch(scene.skill_button);check(scene.aiming_skill==0,"same touch action cancels ground targeting")
	await touch(scene.skill_button);var origin: Vector2=w.player;var target: Vector2=origin+Vector2(.5,0)
	var screen: Vector2=(scene.iso(target)+scene.camera_origin)*scene.world_zoom
	await touch_at(screen);check(scene.aiming_skill==0 and w.player.distance_to(target)<.05,"actual visible-ground touch warps to chosen location")
	w.attack_cooldown=0;w.enemies=[{"monster_id":5,"name":"Selected creature","hp":10000,"max_hp":10000,"alive":true,"x":w.player.x+.5,"y":w.player.y,"cooldown":100.0}];scene.queue_redraw();await process_frame;await process_frame
	screen=(scene.iso(Vector2(w.enemies[0]["x"],w.enemies[0]["y"]))+scene.camera_origin+Vector2(0,-30))*scene.world_zoom
	await touch_at(screen);check(w.selected_enemy==w.enemies[0],"tap on creature selects it for attack and rush targeting")
	check(scene.dp_bar.get_global_rect().end.y<scene.help_label.position.y and scene.run_button.get_global_rect().end.y<scene.joystick.position.y+30,"new HUD controls keep separate readable space")
	var art: Dictionary=scene.art;var groups: int=0
	for id in range(9):
		var server_id: int=7 if id==6 else 6 if id==7 else id
		if art["actor_states"].get(str(server_id),{}).has("attack"):groups+=1
	check(groups==9,"all nine heroes have original attack frames available")
	if DisplayServer.get_name()!="headless":
		w.character_id=1;w.level=10;w.danger=w.max_danger();w.skills.reset();w.skills.ensure_slots();scene._update_ui();scene.queue_redraw();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v15-hud.png")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute("user://recovery-ui.json"+suffix)
	scene.queue_free();await process_frame;print("RECOVERY UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
