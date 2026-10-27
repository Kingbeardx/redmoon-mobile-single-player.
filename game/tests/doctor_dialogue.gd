extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,text: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(text)
func find_help(node: Node) -> Button:
	if node is Button and node.text=="WHAT SHOULD I DO NEXT?":return node
	for child in node.get_children():
		var found:=find_help(child)
		if found!=null:return found
	return null
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.frontend.close_for_play();scene.set_process(false)
	scene.world.create_character("Patient",2)
	var npc: Dictionary=scene.world.nearest_npc()
	scene.game_ui.open_dialogue(npc)
	check(scene.game_ui.dialogue_text.text.contains("I’m the Doctor"),"doctor introduces herself")
	find_help(scene.game_ui.panel).emit_signal("pressed")
	check(scene.game_ui.dialogue_text.text.contains("BEGIN TRAINING") and scene.world.tutorial_stage==0,"doctor help explains her available training choice without claiming it")
	scene.game_ui.dialogue_primary.emit_signal("pressed")
	check(scene.world.tutorial_stage==1,"training choice still grants introduction")
	find_help(scene.game_ui.panel).emit_signal("pressed")
	check(scene.game_ui.dialogue_text.text.contains("Street 1 first"),"doctor directs first town visit")
	scene.world.tutorial_stage=2;scene.world.tutorial_kills=1;scene.game_ui.open_dialogue(npc)
	find_help(scene.game_ui.panel).emit_signal("pressed")
	check(scene.game_ui.dialogue_text.text.contains("1 of 3"),"doctor describes remaining training")
	scene.world.tutorial_stage=3;scene.game_ui.open_dialogue(npc)
	find_help(scene.game_ui.panel).emit_signal("pressed")
	check(scene.game_ui.dialogue_text.text.contains("COMPLETE TRAINING") and not scene.game_ui.dialogue_text.text.contains("Return to Street"),"doctor offers reward instead of asking player to return to herself")
	var gold: int=scene.world.gold;scene.game_ui.dialogue_primary.emit_signal("pressed")
	check(scene.world.tutorial_stage==4 and scene.world.gold==gold+100,"reward still completes once")
	find_help(scene.game_ui.panel).emit_signal("pressed")
	check(scene.game_ui.dialogue_text.text.contains("training is complete"),"completed training gives exploration guidance")
	scene.world.adventure_started=false;scene.world.hp=1;scene.world.mana=0;scene.game_ui.open_dialogue(npc)
	check(scene.game_ui.dialogue_primary.text=="RESTORE HEALTH & MANA","older saves are offered working healing service")
	scene.game_ui.dialogue_primary.emit_signal("pressed")
	check(scene.world.hp==scene.world.max_hp() and scene.world.mana==scene.world.max_mana(),"legacy patient is healed without restarting progress")
	print("DOCTOR DIALOGUE: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
