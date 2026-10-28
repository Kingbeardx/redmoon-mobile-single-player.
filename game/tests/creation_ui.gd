extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func press_row(scene: Node, prefix: String) -> bool:
	for row in scene.inventory_list.get_children():
		if row.text.begins_with(prefix): row.emit_signal("pressed");return true
	return false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene)
	await process_frame
	check(scene.frontend.panel.visible,"title opens before gameplay")
	check(not scene.frontend.has_save,"clean installation has no continue save")
	var start: Vector2=scene.world.player
	scene._process(1.0)
	check(scene.world.player==start and scene.autosave_elapsed==0,"title pauses game and autosave")
	scene.frontend.show_creation()
	check(scene.frontend.hero_buttons.size()==9 and scene.frontend.preview.texture!=null,"nine selectable heroes with original sprite preview")
	scene.frontend.name_input.text="A";scene.frontend._begin()
	check(scene.frontend.panel.visible and scene.frontend.feedback.text.to_lower().contains("name"),"invalid name remains in creation")
	scene.frontend.name_input.text="TestHero";scene.frontend.select_hero(2);scene.frontend._begin()
	check(not scene.frontend.panel.visible and scene.world.map_id==9 and scene.world.player_name=="TestHero","begin enters safe town as named selected hero")
	check(scene.map_select.get_item_text(0).contains("Hospital"),"travel menu displays town name")
	scene.game_ui.talk_nearby()
	check(scene.game_ui.page=="dialogue" and scene.game_ui.dialogue_primary!=null,"doctor dialogue available")
	scene.game_ui.dialogue_primary.emit_signal("pressed")
	check(scene.world.tutorial_stage==1 and scene.world.gold==50 and scene.world.message.begins_with("Doctor:"),"doctor dialogue advances beginner objective")
	scene._travel_rows();press_row(scene,"Travel to Street 1")
	check(scene.world.map_id==1 and scene.world.tutorial_stage==2,"town guide UI reaches Street 1")
	scene._travel_rows();press_row(scene,"Travel to Backyard")
	check(scene.world.map_id==0,"town guide UI reaches beginner combat zone")
	scene.world.combat.random.seed=7
	for i in range(3):
		scene.world.enemies=[{"monster_id":1,"x":scene.world.player.x,"y":scene.world.player.y,"hp":1,"alive":true}]
		for attempt in range(20):
			if not scene.world.enemies[0]["alive"]:break
			scene.world.attack_cooldown=0;scene.attack_button.emit_signal("pressed")
	check(scene.world.tutorial_stage==3,"attack control completes training")
	var earned_gold: int=scene.world.gold
	scene._travel_rows();press_row(scene,"Travel to Street 1 Hospital")
	scene.game_ui.talk_nearby();scene.game_ui.dialogue_primary.emit_signal("pressed")
	check(scene.world.tutorial_stage==4 and scene.world.gold==earned_gold+100,"return and Doctor dialogue complete beginner journey")
	scene._travel_rows();press_row(scene,"Travel to Street 1 Food Shop")
	scene._market_rows()
	var before: int=int(scene.world.inventory.get("4:1",0))
	for item in scene.world.zone_stock():
		if item["key"]=="4:1":scene.game_ui.shop_selection=item["purchase_key"]
	scene.game_ui.show_shop();scene.game_ui.shop_buy_button.emit_signal("pressed")
	check(int(scene.world.inventory.get("4:1",0))==before+1 and scene.world.gold==earned_gold+100-50,"food shop UI purchases source-priced food")
	scene.frontend.show_title();scene.frontend.show_creation()
	scene.frontend.name_input.text="Replacement";scene.frontend._begin()
	check(scene.frontend.replace_dialog.visible and scene.world.player_name=="TestHero","replacing existing save requires confirmation")
	scene.frontend.replace_dialog.hide();scene.frontend.show_title();scene.frontend.close_for_play()
	check(scene.world.player_name=="TestHero","cancel preserves existing character")
	var saved=scene.world.read_json("user://progress.json")
	check(saved["player_name"]=="TestHero" and int(saved["tutorial_stage"])==4,"new player progress is saved")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v05-first-town.png")
	print("CREATION UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
