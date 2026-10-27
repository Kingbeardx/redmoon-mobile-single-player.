extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func find_button(node: Node,prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):return node
	for child in node.get_children():
		var found: Button=find_button(child,prefix)
		if found!=null:return found
	return null
func press(scene,prefix: String) -> void:
	var button: Button=find_button(scene.game_ui.content,prefix)
	if button==null:check(false,"missing button "+prefix);quit(1);await process_frame;return
	var parent: Node=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await process_frame;await process_frame
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame;await process_frame
func touch(scene,button: Button) -> void:
	for down in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=2;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true)
	await process_frame
func talk(scene,role: String) -> void:
	scene.queue_redraw();await process_frame;await process_frame
	for npc in scene.world.story.data["npcs"]:
		if npc["story_role"]!=role:continue
		for down in [true,false]:
			var e:=InputEventScreenTouch.new();e.index=1;e.pressed=down;e.position=scene.npc_screen_rect(npc).get_center();root.push_input(e,true)
		await process_frame;await process_frame;return
func boss(w,id: int) -> Dictionary:
	for enemy in w.enemies:
		if int(enemy["monster_id"])==id:return enemy
	return {}
func step(scene,seconds: int=6) -> void:
	for i in range(seconds):scene.world.tick(.1,Vector2.ZERO)
	scene._update_ui();scene.queue_redraw()
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false);scene.frontend.close_for_play()
	var w=scene.world;w.create_character("ChapterTester",1,"user://chapter-ui.json");w.level=50;w.honor=100;w.story.update();scene.game_ui.show_journal()
	await press(scene,"STORY ·");check(scene.game_ui.page=="story","journal opens recovered story chapter")
	await press(scene,"GUIDE TO SPY'S HOUSE");check(w.map_id==74 and not scene.game_ui.panel.visible,"actual guide button reaches Spy house")
	var spy: Dictionary=boss(w,90);w.player=Vector2(spy["x"]-.1,spy["y"]);scene._update_ui()
	for i in range(40):
		if not spy["alive"]:break
		if w.hp<30:await touch(scene,scene.heal_button)
		await touch(scene,scene.attack_button);step(scene)
	check(w.story.has(2) and int(w.inventory.get("5:1",0))==1,"touch combat defeats Spy and recovers quest film")
	check(w.map_id==74,"Spy encounter is survivable using existing healing control")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v13-spy.png")
	scene.game_ui.show_story();await press(scene,"GUIDE TO DOWNTOWN 2");await talk(scene,"archeologist")
	check(scene.game_ui.page=="story_dialogue" and scene.game_ui.dialogue_text.text.contains("microfilm"),"tapping original Archeologist opens recovered dialogue")
	await press(scene,w.story.text(192));check(w.story.has(4),"actual quiz choice decodes Microfilm")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v13-dialogue.png")
	await press(scene,"QUEST JOURNAL");await press(scene,"GUIDE TO STREET 3");await talk(scene,"geographer")
	await press(scene,"MAKE THE MAP")
	check(w.honor_cap()==300,"actual Geographer dialogue raises honor cap")
	await press(scene,"QUEST JOURNAL");await press(scene,"GUIDE TO KASHAM'S HOUSE");await talk(scene,"kasham");await press(scene,"ACCEPT ESPER MISSION")
	check(w.story.has(16),"actual Kasham dialogue accepts Esper mission")
	await press(scene,"QUEST JOURNAL");await press(scene,"GUIDE TO SAHARA DUNGEON 1")
	var esper: Dictionary=boss(w,92);check(not esper.is_empty(),"mission guide reaches actual quest Esper")
	w.player=Vector2(esper["x"]-.1,esper["y"]);w.skills.assign(1,12);scene._update_ui()
	for i in range(65):
		if w.story.has(32):break
		if w.hp<30 or w.mana<6 and w.hp<w.max_hp():await touch(scene,scene.heal_button)
		if i%4==0:await touch(scene,scene.extra_skill_buttons[0])
		else:await touch(scene,scene.skill_button)
		step(scene,9)
		if w.map_id!=72:break
	check(w.story.has(32),"touch spell combat with Ice Rain clears adds and defeats Esper")
	check(w.map_id==72,"Esper mission is survivable with existing spells and heals")
	scene.game_ui.show_story();await press(scene,"GUIDE TO KASHAM'S HOUSE");await talk(scene,"kasham");await press(scene,"REPORT ESPER'S DEFEAT")
	check(w.story.complete() and w.honor_cap()==400,"NPC tap and report complete recovered chapter")
	check(int(w.inventory.get("5:102",0))==1,"original Sahara map reward reaches inventory")
	scene.game_ui.show_story();await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v13-story.png")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute("user://chapter-ui.json"+suffix)
	scene.queue_free();await process_frame;print("STORY UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
