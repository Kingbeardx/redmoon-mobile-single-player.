extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for _i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else "user://preview.png"
	var result: Error = root.get_texture().get_image().save_png(path)
	print("PREVIEW: ", path, " result=", result)
	quit(0 if result == OK else 1)
