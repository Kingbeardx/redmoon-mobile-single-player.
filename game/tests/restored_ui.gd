extends SceneTree
var failures: int=0
var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;w.create_character("Recovery",3,"user://restored-ui.json");w.enter_map(0);w.enemies=[]
	var row: Dictionary=w.skills.entry(33);w.level=int(row["level"]);w.honor=int(row["honor"]);w.stats["spirit"]=15000;w.mana=w.max_mana();w.skills.reset();w.skills.assign(0,33)
	var destination: Vector2=w.player
	for y in range(maxi(0,int(w.player.y)-6),mini(w.height,int(w.player.y)+6)):
		for x in range(maxi(0,int(w.player.x)-6),mini(w.width,int(w.player.x)+6)):
			var p:=Vector2(x+.5,y+.5)
			if w.can_stand(p) and p.distance_to(w.player)>2 and p.distance_to(w.player)<5 and w.clear_sight(w.player,p):destination=p
	check(destination!=w.player,"visible distant loot location available")
	w.drop_loot("1:1",destination);scene._update_ui();scene.queue_redraw();await process_frame;await process_frame
	check(w.ground_loot.size()==1 and not scene.skill_button.disabled,"Psycho Kinesis has usable hotbar action and visible loot")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v16-loot.png")
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=2;event.pressed=down;event.position=scene.skill_button.get_global_rect().get_center();root.push_input(event,true)
	await process_frame;await process_frame
	check(w.ground_loot.is_empty() and int(w.inventory.get("1:1",0))>0,"real touch casts Psycho Kinesis and collects loot")
	scene.queue_free();await process_frame;print("RESTORED UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
