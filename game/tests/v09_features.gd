extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,text: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.frontend.close_for_play();scene.set_process(false);var w=scene.world
	w.create_character("Caster",1)
	check(w.HERO_NAMES[6]=="Kitara" and w.HERO_NAMES[7]=="Lunarena","hero IDs follow original message table")
	check(w.equipment_reason("1:52")=="Not for Azlar","caster gun restriction explained")
	w.travel_to(10);w.gold=100000;scene.game_ui.show_shop()
	var all_compatible: bool=true
	for purchase in scene.game_ui.shop_buttons:
		for item in w.zone_stock():
			if item["purchase_key"]==purchase and w.equipment_reason(item["key"]).begins_with("Not for"):all_compatible=false
	check(all_compatible,"caster stock filter hides incompatible weapons")
	scene.game_ui.shop_hero_only=false
	for item in w.zone_stock():
		if item["key"]=="1:52":scene.game_ui.shop_selection=item["purchase_key"]
	scene.game_ui.show_shop()
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v09-shop.png")
	check(scene.game_ui.shop_buttons.size()>0 and scene.game_ui.shop_buy_button.disabled,"all-stock inspection cannot buy incompatible gun")
	var stock: Dictionary={}
	for item in w.zone_stock():
		if item["key"]=="1:52":stock=item
	var gold: int=w.gold
	check(not w.buy_stock(stock["purchase_key"]) and w.gold==gold,"backend blocks incompatible purchase without taking gold")
	w.character_id=2;scene.game_ui.shop_hero_only=true;scene.game_ui.shop_selection="";scene.game_ui.show_shop()
	check(scene.game_ui.shop_buttons.size()>0 and not scene.game_ui.shop_buy_button.disabled,"sword hero has compatible purchase choices")
	await process_frame;await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=scene.game_ui.shop_buy_button.get_global_rect().get_center();root.push_input(event,true)
	check(w.gold<gold,"compatible purchase works through GUI input")
	scene.game_ui.close();w.travel_to(0)
	check(w.enemies.any(func(e: Dictionary)->bool:return float(e.get("respawn_seconds",99999))<=60),"beginner population contains regular fast-respawn source groups")
	var enemy: Dictionary=w.enemies[0];enemy["alive"]=false;enemy["hp"]=0;enemy["respawn_timer"]=10
	w.advance_respawns(9);check(not enemy["alive"],"respawn does not occur early")
	w.advance_respawns(1.1);check(enemy["alive"] and enemy["hp"]==36,"defeated mob returns with health")
	enemy["alive"]=false;enemy["respawn_timer"]=1;scene.game_ui.show_bag();scene._process(1.1)
	check(enemy["alive"],"respawn countdown continues while menus are open")
	scene.game_ui.close();enemy["alive"]=false;enemy["respawn_timer"]=10;w.remember_map();w.map_states[str(w.map_id)]["respawn_saved_at"]=Time.get_unix_time_from_system()-11
	w.enter_map(9);w.map_states["0"]["respawn_saved_at"]=Time.get_unix_time_from_system()-11;w.enter_map(0)
	check(w.enemies[0]["alive"],"away-time is accounted for after changing maps")
	w.enemies=[]
	for i in range(18):w.enemies.append({"monster_id":5,"x":w.player.x,"y":w.player.y,"hp":0,"alive":false,"respawn_seconds":3600,"respawn_timer":3600})
	w.remember_map();w.enter_map(9);w.enter_map(0)
	check(w.enemies.any(func(e: Dictionary)->bool:return float(e.get("respawn_seconds",99999))<=60),"legacy slow-only saved population gains regular respawning groups")
	w.enemies=[];w.remember_map();w.enter_map(9);w.enter_map(0)
	check(not w.enemies.is_empty(),"empty legacy outdoor state repopulates from source spawns")
	var path: String="user://roster-test.json";w.character_id=6;w.save_game(path)
	var saved: Dictionary=w.read_json(path);saved.erase("roster_version");var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(saved));f.close()
	var restored=load("res://scripts/world.gd").new();restored.initialize();restored.load_game(path)
	check(restored.character_id==7 and restored.HERO_NAMES[restored.character_id]=="Lunarena","old heroine save retains intended selected identity")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute(path+suffix)
	check(scene.frontend.profiles.size()==9 and str(scene.frontend.profiles["1"]["story"]).contains("brother"),"original character biography recovered")
	scene.frontend.show_creation();scene.frontend.select_hero(1);scene.frontend.show_bio()
	check(scene.frontend.bio_panel.visible,"character story and equipment modal opens")
	scene.frontend.bio_panel.hide();scene.frontend.close_for_play();w.travel_to(9);scene._update_ui()
	check(not scene.root_ui.has_node("TopPanel") and not scene.root_ui.has_node("BottomPanel"),"opaque full-width HUD bars removed")
	check(scene.skill_button.visible and scene.food_button.visible and scene.hp_bar.size.y>=30,"icon skill and item hotbar with readable health gauge")
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","wide phone canvas expands without fixed-aspect letterboxing")
	w.character_id=1;w.skills.reset();w.mana=50;w.attack_cooldown=0;w.enemies=[{"monster_id":1,"x":w.player.x,"y":w.player.y,"hp":100,"alive":true}]
	scene._update_ui()
	for pressed in [true,false]:
		var touch:=InputEventScreenTouch.new();touch.index=1;touch.pressed=pressed;touch.position=scene.skill_button.get_global_rect().get_center();root.push_input(touch,true)
	check(w.mana==47 and w.enemies[0]["hp"]<100,"visible class skill slot casts Psychic Shock at original percentage cost")
	w.inventory["4:1"]=1;w.hp=1;scene._update_ui()
	for pressed in [true,false]:
		var touch:=InputEventScreenTouch.new();touch.index=1;touch.pressed=pressed;touch.position=scene.food_button.get_global_rect().get_center();root.push_input(touch,true)
	check(w.hp==w.max_hp() and w.inventory["4:1"]==0,"visible food slot consumes suitable inventory food")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1600,720);await process_frame;await process_frame;scene._layout()
		check(scene.get_viewport_rect().size.x>1590 and scene.root_ui.size.x>1590,"wide phone canvas fills the display without side letterboxing")
		w.enemies=[];w.character_id=1;w.attack_flash=0;w.inventory["4:1"]=5;w.message="Tap a person to talk";scene._update_ui()
		scene.queue_redraw();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v09-hud.png")
		scene.frontend.show_title();scene.frontend.show_creation();scene.frontend.select_hero(1);scene.frontend.show_bio();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v09-bio.png")
	print("V09 FEATURES: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
