extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for _i in range(10):
		await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size()>1 and args[1] in ["creation","keyboard"]:
		scene.frontend.show_creation()
		if args[1]=="keyboard": scene.frontend.open_keyboard()
	elif args.size()>1 and args[1]=="play": scene.frontend.close_for_play()
	if args.size()>1 and args[1]=="inventory":
		scene.world.inventory={"1:1":1,"2:1":1,"4:1":2}
		scene._show_inventory()
		await process_frame
		scene.inventory_list.get_parent().scroll_vertical=650
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = args[0] if not args.is_empty() else "user://preview.png"
	var result: Error = root.get_texture().get_image().save_png(path)
	print("PREVIEW: ", path, " result=", result)
	quit(0 if result == OK else 1)
