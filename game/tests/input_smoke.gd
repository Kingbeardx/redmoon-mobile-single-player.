extends SceneTree

var failures: int = 0

func verify(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.frontend.close_for_play()
	scene.set_process(false)
	var pad: Vector2 = scene.joystick.global_position + scene.joystick.size * 0.5 + Vector2(40, 0)
	touch(0, pad, true)
	verify(scene.joystick.direction.x > 0.5, "First touch moves joystick")
	scene.world.attack_cooldown = 0.0
	touch(1, scene.attack_button.get_global_rect().get_center(), true)
	verify(scene.world.attack_cooldown > 0, "Second touch attacks while joystick is held")
	verify(scene.joystick.active_touch == 0, "Attack preserves joystick finger")
	touch(1, scene.attack_button.get_global_rect().get_center(), false)
	touch(0, pad, false)
	verify(scene.joystick.direction == Vector2.ZERO, "Joystick release stops movement")
	scene.world.hp = 10
	var heals: int = scene.world.potions
	touch(2, scene.heal_button.get_global_rect().get_center(), true)
	touch(2, scene.heal_button.get_global_rect().get_center(), false)
	verify(scene.world.hp == 55 and scene.world.potions == heals - 1, "Healing touch consumes exactly one charge")
	print("INPUT SMOKE: 5 checks, %d failures" % failures)
	quit(1 if failures else 0)
