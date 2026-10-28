extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func click(button: Button) -> void:
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame;await process_frame
func find_button(node: Node,text: String) -> Button:
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var button: Button=find_button(child,text)
		if button!=null:return button
	return null
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;w.create_character("Rebuilt",0,"user://reconstruction-ui.json");scene.game_ui.show_party();await process_frame;await process_frame
	var recruit: Button=find_button(scene.game_ui.panel,"RECRUIT Philar");check(recruit!=null,"party UI offers actual hero recruitment")
	await click(recruit);check(w.party.allies.size()==1,"actual UI click recruits a companion")
	scene.game_ui.close();var row: Dictionary=w.skills.entry(301);w.level=int(row["level"]);w.honor=int(row["honor"]);w.stats["spirit"]=15000;w.stats["power"]=1000;w.hp=w.max_hp();w.mana=w.max_mana();w.party.allies[0]["hp"]=0;w.skills.reset();w.skills.assign(0,301);w.attack_cooldown=0;scene._update_ui();await process_frame
	var hp: int=w.hp
	for down in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=2;e.pressed=down;e.position=scene.skill_button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame;await process_frame
	check(w.party.allies[0]["hp"]>0 and w.hp==hp-hp/2 and w.mana==0,"touch Resurrection revives fallen ally at source cost")
	w.story.flags=127;scene.game_ui.show_campaign();await process_frame;await process_frame
	var begin: Button=find_button(scene.game_ui.panel,"BEGIN CONTINUATION");check(begin!=null and not begin.disabled,"continuation has an accessible start action")
	await click(begin);check(w.campaign.stage==0,"actual UI starts reconstructed continuation")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v18-campaign.png")
	scene.game_ui.show_multiplayer();await process_frame;await process_frame
	check(find_button(scene.game_ui.panel,"HOST CO-OP")!=null and find_button(scene.game_ui.panel,"JOIN HOST")!=null,"co-op exposes real host and join actions")
	check(find_button(scene.game_ui.panel,"CLEAR")!=null,"mobile address input includes an on-screen keypad")
	scene.queue_free();await process_frame;print("RECONSTRUCTION UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
