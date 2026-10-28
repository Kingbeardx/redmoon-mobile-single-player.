extends SceneTree

const World = preload("res://scripts/world.gd")
var failures: int = 0
var checks: int = 0

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var world = World.new()
	verify(world.initialize(), "Loads real recovered data")
	verify(world.catalog.size() == 196, "All 196 recovered maps available")
	verify(world.width == 150 and world.height == 200, "Original map 0 dimensions")
	verify(world.can_stand(world.player), "Starting position is traversable")
	verify(world.enemies.size() > 0, "Real spawn records produce enemies")
	verify(not world.is_open(Vector2i(-1, 0)) and not world.is_open(Vector2i(150, 0)), "Out of bounds is blocked")
	verify(not world.is_open(Vector2i(0, 0)), "Original zero boundary is blocked")
	var map_start: Vector2 = world.player
	for _frame in range(120):
		world.tick(1.0 / 60.0, Vector2.RIGHT)
	verify(world.player.distance_to(map_start) > 0.5, "Movement traverses real map")
	verify(world.can_stand(world.player), "Movement stays on decoded traversable tiles")
	# A narrow fixture proves substeps stop at an intervening wall.
	var collision = World.new()
	collision.width = 5
	collision.height = 3
	collision.walkable = [0,0,0,0,0, 0,1,0,1,0, 0,0,0,0,0]
	var result: Vector2 = collision.move_entity(Vector2(1.5, 1.5), Vector2(2, 0))
	verify(result.x < 2.0, "Large movement cannot tunnel through a blocked cell")
	# Isolate combat from spawn distribution; source identity is preserved.
	world.enemies = [{"monster_id":5,"name":"test","x":world.player.x,"y":world.player.y,"hp":36,"max_hp":36,"cooldown":100.0,"alive":true}]
	verify(world.attack(), "In-range attack hits")
	verify(not world.attack(), "Cooldown prevents instant repeated hits")
	world.tick(0.1, Vector2.ZERO)
	world.attack_cooldown = 0.0
	world.attack()
	world.attack_cooldown = 0.0
	world.attack()
	verify(world.defeated == 1 and world.xp == 2, "Defeat awards source XP with original per-level cap once")
	world.attack_cooldown = 0.0
	verify(not world.attack() and world.xp == 2, "Dead enemies cannot award XP twice")
	world.hp = 50
	verify(world.heal() and world.hp == 95 and world.potions == 4, "Heal consumes inventory and restores health")
	var path: String = "user://smoke-save.json"
	verify(world.save_game(path) == OK, "Save writes successfully")
	var restored = World.new()
	verify(restored.initialize() and restored.load_game(path), "Fresh world loads saved progress")
	verify(restored.hp == world.hp and restored.xp == world.xp and restored.potions == world.potions, "Player values round-trip")
	verify(restored.player.distance_to(world.player) < 0.001 and not restored.enemies[0]["alive"], "Position and defeated enemies round-trip")
	verify(restored.enter_map(1) and restored.enter_map(0), "Switch maps and restore previous state")
	verify(not restored.enemies[0]["alive"], "Map switch retains defeated enemies")
	var good_save: Dictionary = world.read_json(path)
	good_save["map_states"]["0"] = "corrupt"
	verify(not world.valid_save(good_save), "Malformed nested map state rejected")
	good_save = world.read_json(path)
	good_save["hp"] = {"bad": true}
	verify(not world.valid_save(good_save), "Non-numeric saved stats rejected")
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{\"version\":999}")
	bad.close()
	verify(not restored.load_game(path), "Unsupported save version rejected")
	DirAccess.remove_absolute(path)
	print("GAME SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
