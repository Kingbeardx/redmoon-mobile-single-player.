extends SceneTree
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	check(scene.ready_world and scene.art.get("actors",{}).size() == 58, "client art and world loaded")
	var start: Vector2 = scene.world.player
	for i in range(60):
		scene.world.tick(1.0/60,Vector2.RIGHT)
	check(scene.world.player.distance_to(start)>0.5,"move in original map")
	var kills: int = scene.world.defeated
	scene.world.enemies = [{"monster_id":5,"x":scene.world.player.x,"y":scene.world.player.y,"hp":36,"max_hp":36,"cooldown":100.0,"alive":true}]
	for i in range(3):
		scene.world.attack_cooldown = 0
		scene.attack_button.emit_signal("pressed")
	check(scene.world.defeated == kills+1,"combat through attack control")
	scene.world.inventory = {"4:1": 1}
	scene.world.hp = 30
	scene._show_inventory()
	for row in scene.inventory_list.get_children():
		if "equip/use" in row.text and "× 1" in row.text:
			row.emit_signal("pressed")
			break
	check(scene.world.hp == 55,"inventory UI uses food")
	scene.inventory_panel.hide()
	scene.save_button.emit_signal("pressed")
	var second = load("res://scripts/world.gd").new()
	second.initialize()
	check(second.load_game() and second.defeated == scene.world.defeated and second.hp == 55,"resume saved session")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/end-to-end.png")
	print("END TO END: 5 checks, ", failures," failures")
	quit(1 if failures else 0)
