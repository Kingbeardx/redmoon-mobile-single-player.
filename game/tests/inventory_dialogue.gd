extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,text: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func click(control: Control) -> void:
	await process_frame;await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=control.get_global_rect().get_center();root.push_input(event,true)
	await process_frame;await process_frame
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.frontend.close_for_play();scene.set_process(false)
	scene.world.create_character("UIHero",2)
	scene.world.inventory["1:1"]=1;scene.world.inventory["2:1"]=1;scene.world.inventory["4:2"]=3
	scene._show_inventory();await process_frame
	check(not scene.joystick.is_processing_input(),"modal suspends underlying joystick input")
	check(scene.game_ui.item_buttons.size()==7,"grid contains positive stacks and starter map items")
	check(scene.game_ui.item_texture("4:1")!=null,"inventory displays original food icon")
	await click(scene.game_ui.item_buttons["4:1"])
	check(scene.game_ui.selected_item=="4:1" and scene.game_ui.item_action.text=="USE ITEM","selecting icon opens item detail")
	scene.world.hp=1
	await click(scene.game_ui.item_action)
	check(scene.world.hp==50 and scene.world.inventory["4:1"]==4,"explicit Use action consumes one stack item")
	scene.game_ui.item_filter="Gear";scene.game_ui.show_bag();await process_frame
	check(scene.game_ui.item_buttons.size()==2,"gear filter hides food and maps")
	await click(scene.game_ui.item_buttons["1:1"]);await click(scene.game_ui.item_action)
	check(scene.world.weapon_bonus==5 and scene.game_ui.item_action.text=="UNEQUIP","equip action updates gear and button")
	await click(scene.game_ui.item_action)
	check(scene.world.weapon_bonus==0 and scene.game_ui.item_action.text=="EQUIP","unequip updates stats")
	scene.world.bonus_points=2;scene.world.stats["power"]=99
	scene.game_ui.show_stats();await process_frame
	await click(scene.game_ui.stat_plus["power"])
	check(scene.game_ui.draft["power"]==1 and scene.world.stats["power"]==99 and scene.world.bonus_points==2,"preview changes do not spend points")
	await click(scene.game_ui.stat_plus["spirit"])
	check(scene.game_ui.stat_plus["power"].disabled and scene.game_ui.draft_total()==2,"allocation cannot overspend")
	await click(scene.game_ui.stat_minus["spirit"])
	check(scene.game_ui.draft_total()==1,"minus undoes pending allocation")
	await click(scene.game_ui.apply_button)
	check(scene.world.stats["power"]==100 and scene.world.max_hp()==110 and scene.world.bonus_points==1,"Apply commits stat and HP preview")
	check(not scene.world.allocate_stats({"power":2}),"backend refuses point overspend")
	check(not scene.world.allocate_stats({"power":-1}) and not scene.world.allocate_stats({"power":0.5}) and not scene.world.allocate_stats({"bad":1}),"backend rejects malformed allocations")
	check(not scene.world.allocate_stats({"power":1},"/not-a-directory/progress.json") and scene.world.stats["power"]==100 and scene.world.bonus_points==1,"save failure rolls back staged stat spending")
	var restored=load("res://scripts/world.gd").new();restored.initialize();restored.load_game()
	check(restored.stats["power"]==100 and restored.bonus_points==1,"applied points persist")
	scene.game_ui.change_stat("power",1);scene.game_ui.close()
	check(scene.world.bonus_points==1 and scene.game_ui.draft.is_empty(),"closing discards unspent draft")
	# A real screen tap must resolve the NPC at every supported zoom.
	for zoom in [1.25,2.0,3.0]:
		scene.set_zoom(zoom);scene.world.enter_map(9);scene.world.player=scene.world.find_start([9,12]);scene.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		var npc: Dictionary=scene.world.nearest_npc()
		var area:=Rect2(Vector2(0,164),scene.get_viewport_rect().size-Vector2(0,318))
		var point: Vector2=scene.npc_screen_rect(npc).intersection(area).get_center()
		for pressed in [true,false]:
			var touch:=InputEventScreenTouch.new();touch.index=0;touch.pressed=pressed;touch.position=point;Input.parse_input_event(touch);await process_frame
		check(scene.game_ui.panel.visible and scene.game_ui.page=="dialogue" and scene.game_ui.speaker["name"]=="+Doctor","tap Doctor at zoom %.2f" % zoom)
		scene.game_ui.close()
	scene.game_ui.talk_nearby();check(scene.world.tutorial_stage==0,"opening conversation does not auto-claim training")
	await click(scene.game_ui.dialogue_primary)
	check(scene.world.tutorial_stage==1 and scene.game_ui.dialogue_text.text.begins_with("Doctor:"),"dialogue choice starts training and displays response")
	scene.game_ui.close();scene.world.enter_map(1);scene.world.enemies=[]
	var npc: Dictionary=scene.world.content["npcs"][0]
	scene.world.player=scene.world.find_start([int(scene.world.npc_position(npc).x)+10,int(scene.world.npc_position(npc).y)])
	scene.pending_npc=npc.duplicate(true)
	for i in range(600):
		scene._process(0.05)
		if scene.game_ui.panel.visible:break
	check(scene.game_ui.panel.visible and scene.world.npc_position(npc).distance_to(scene.world.player)<8,"walk-to-NPC path opens conversation on arrival")
	check(not scene.world.npc_has_shop(npc),"quest NPCs do not impersonate merchants")
	scene.game_ui.close();scene.pending_npc=npc.duplicate(true);scene.joystick.direction=Vector2.RIGHT;scene._process(0.05)
	check(scene.pending_npc.is_empty(),"manual movement cancels walk-to-talk")
	scene.joystick.direction=Vector2.ZERO;scene.world.travel_to(5);scene.world.player=scene.world.find_start([9,12])
	scene.game_ui.talk_nearby();await process_frame
	check(scene.game_ui.dialogue_primary!=null and scene.game_ui.dialogue_primary.text=="BROWSE SHOP","merchant dialogue offers shop")
	await click(scene.game_ui.dialogue_primary)
	check(scene.inventory_panel.visible and not scene.game_ui.panel.visible and scene.world.shop_available,"shop dialogue opens recovered stock")
	scene.world.enter_map(0);check(not scene.world.shop_available,"leaving shop clears sale permission")
	# Capture the actual bag and stat panels for review.
	scene.world.travel_to(9);scene.world.inventory["1:1"]=1;scene.world.inventory["2:1"]=1;scene.game_ui.item_filter="All";scene.game_ui.selected_item="1:1";scene.game_ui.show_bag()
	await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v07-bag.png")
	scene.game_ui.show_stats();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v07-stats.png")
	scene.game_ui.close();scene.world.player=scene.world.find_start([9,12]);scene.game_ui.talk_nearby();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v07-dialogue.png")
	print("INVENTORY / DIALOGUE: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
