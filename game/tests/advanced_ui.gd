extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;w.create_character("Honored",8,"user://advanced-ui.json");w.level=200;w.honor=50;w.stats["spirit"]=300;w.mana=w.max_mana();scene.game_ui.selected_skill=84;scene.game_ui.show_skills()
	await process_frame;await process_frame
	check(not scene.game_ui.skill_cast_button.disabled,"earned honor allows matching original branch in UI")
	check(scene.game_ui.skill_assign_buttons.all(func(b:Button)->bool:return not b.disabled),"honor-unlocked skill can bind to every touch slot")
	scene.game_ui.show_journal();check(scene.game_ui.page=="journal","journey honor guide opens")
	scene.game_ui.close();w.character_id=1;w.level=1;w.stats["spirit"]=10;w.honor=0;w.skills.reset();w.skills.ensure_slots();w.travel_to(0)
	var start: Vector2=w.player;var pos: Vector2=start
	for x in range(-4,5):
		for y in range(-4,5):
			var next:=start+Vector2(x,y)
			if next.distance_to(start)>2 and next.distance_to(start)<5 and w.can_stand(next) and w.clear_sight(start,next):pos=next
	w.enemies=[{"monster_id":153,"hp":36,"alive":true,"x":pos.x,"y":pos.y,"cooldown":100.0}];w.mana=50;w.attack_cooldown=0
	check(w.expected_honor(153)==1,"visible target label predicts positive honor reward")
	scene._update_ui()
	var skill: Button=scene.skill_button
	for down in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=3;e.pressed=down;e.position=skill.get_global_rect().get_center();root.push_input(e,true)
	check(w.mana==47 and w.enemies[0]["hp"]==18,"touch casts original projectile spell at creature")
	check(w.skills.effects.any(func(e:Dictionary)->bool:return int(e.get("skill_id",0))==11),"spell effect carries original projectile reference")
	for effect in w.skills.effects:effect["remaining"]=.30
	scene.queue_redraw();await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v11-projectile.png")
	w.damage_enemy(w.enemies[0],100);check(w.honor==1,"killing visible faction target awards predicted honor")
	scene.game_ui.selected_skill=19;w.level=300;w.honor=-300;w.stats["spirit"]=15000;w.mana=w.max_mana();scene.game_ui.show_skills();await process_frame;await process_frame
	check(not scene.game_ui.skill_cast_button.disabled,"advanced reconstructed skill inspectable for preserved higher-honor character")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v11-skills.png")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute("user://advanced-ui.json"+suffix)
	scene.queue_free();await process_frame;print("ADVANCED UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
