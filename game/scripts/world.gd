extends RefCounted
## Deterministic offline sandbox. Content IDs and placement bounds are recovered;
## movement speed, HP, damage, XP progression and AI are provisional game rules.

const SAVE_VERSION: int = 1
const MOVE_SPEED: float = 5.0
const BASE_POWER: int = 90
# Recovered InitializeHPMax: 50 + floor(P/15)*floor(P/10).
const PLAYER_HP: int = 50 + (BASE_POWER / 15) * (BASE_POWER / 10)
const MAX_ENEMIES: int = 18

var gold: int = 0
var inventory: Dictionary = {}
var armor_bonus: int = 0
var weapon_bonus: int = 0
var character_id: int = 1
var mana: int = 50
var bounty_claimed: bool = false
var motion: Vector2 = Vector2.ZERO
var facing: int = 6
var running: bool = false
var navigation: AStarGrid2D
var exits: Dictionary = {}
var exit_marker_cache: Dictionary = {}
var shop_available: bool = false
var purchases: Dictionary = {}
var item_tables: Dictionary = {}
var catalog: Array = []
var content: Dictionary = {}
var current_map: Dictionary = {}
var map_id: int = -1
var width: int = 0
var height: int = 0
var walkable: Array = []
var player: Vector2 = Vector2.ZERO
var enemies: Array = []
var hp: int = PLAYER_HP
var xp: int = 0
var level: int = 1
var potions: int = 5
var defeated: int = 0
var attack_cooldown: float = 0.0
var attack_flash: float = 0.0
var elapsed: float = 0.0
var message: String = "Explore a recovered map. Combat rules are provisional."
var map_states: Dictionary = {}
var data_root: String = "res://data"
var load_error: String = ""

func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func initialize(root: String = "res://data") -> bool:
	data_root = root
	var portal_data = read_json(data_root + "/client-events.json")
	if portal_data is Dictionary:
		exits = portal_data
	var binary = read_json(data_root + "/binary-content.json")
	if binary is Dictionary:
		for table in binary.get("tables", []):
			if table.get("kind") == "items":
				for item in table.get("records", []):
					item_tables["%d:%d" % [int(table.get("category",0)), int(item.get("slot",0))]] = item.get("name", "Item")
	var index: Variant = read_json(data_root + "/maps.json")
	var tables: Variant = read_json(data_root + "/content.json")
	if not index is Dictionary or not index.get("maps") is Array:
		load_error = "Recovered maps are missing. Run the import tools and copy data into game/data."
		return false
	catalog = index["maps"]
	if catalog.is_empty():
		load_error = "No recovered maps are available."
		return false
	if tables is Dictionary:
		content = tables
	else:
		load_error = "Monster content is missing; map exploration is available."
	var initial: int = int(catalog[0].get("id", 0))
	# Map 0 is the original distribution's first outdoor map when available.
	for entry in catalog:
		if int(entry.get("id", -1)) == 0:
			initial = 0
			break
	return enter_map(initial)

func enter_map(id: int, keep_current: bool = true) -> bool:
	var entry: Dictionary = {}
	for candidate in catalog:
		if int(candidate.get("id", -1)) == id:
			entry = candidate
			break
	if entry.is_empty():
		return false
	var path: String = str(entry.get("path", "maps/%05d.json" % id))
	# Catalog paths are local, generated content; reject traversal on reload.
	if path.is_absolute_path() or ".." in path.split("/"):
		return false
	var decoded: Variant = read_json(data_root + "/" + path)
	if not decoded is Dictionary:
		return false
	var w: int = int(decoded.get("width", 0))
	var h: int = int(decoded.get("height", 0))
	var cells: Variant = decoded.get("walkable")
	if w <= 0 or h <= 0 or w > 2048 or h > 2048 or not cells is Array or cells.size() != w * h:
		return false
	if keep_current and map_id >= 0:
		remember_map()
	current_map = decoded
	map_id = id
	width = w
	height = h
	walkable = cells
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(0,0,width,height)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for y in range(height):
		for x in range(width):
			if not is_open(Vector2i(x,y)):
				navigation.set_point_solid(Vector2i(x,y))
	player = find_start(decoded.get("start", entry.get("start", [w / 2, h / 2])))
	enemies = []
	if map_states.has(str(id)):
		restore_map_state(map_states[str(id)])
	else:
		spawn_enemies()
	attack_cooldown = 0.0
	attack_flash = 0.0
	message = "Map %05d · recovered geometry / provisional collision" % id
	return true

func is_open(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height and int(walkable[cell.y * width + cell.x]) != 0

func can_stand(position: Vector2) -> bool:
	# Small footprint prevents clipping diagonally through blocked corners.
	var radius: float = 0.18
	for offset in [Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(-radius, radius), Vector2(radius, radius)]:
		if not is_open(Vector2i((position + offset).floor())):
			return false
	return true

func find_start(preferred: Variant) -> Vector2:
	var origin := Vector2i(width / 2, height / 2)
	if preferred is Array and preferred.size() >= 2:
		origin = Vector2i(int(preferred[0]), int(preferred[1]))
	origin.x = clampi(origin.x, 0, width - 1)
	origin.y = clampi(origin.y, 0, height - 1)
	if can_stand(Vector2(origin) + Vector2(0.5, 0.5)):
		return Vector2(origin) + Vector2(0.5, 0.5)
	for radius in range(1, maxi(width, height)):
		for dy in range(-radius, radius + 1):
			for dx in [-radius, radius]:
				var point := Vector2(origin + Vector2i(dx, dy)) + Vector2(0.5, 0.5)
				if can_stand(point):
					return point
		for dx in range(-radius + 1, radius):
			for dy in [-radius, radius]:
				var point := Vector2(origin + Vector2i(dx, dy)) + Vector2(0.5, 0.5)
				if can_stand(point):
					return point
	return Vector2(origin) + Vector2(0.5, 0.5)

func spawn_enemies() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 38921 + map_id
	var records: Array = content.get("spawns", [])
	var candidates: Array = []
	for record in records:
		if int(record.get("map_id", -1)) == map_id and int(record.get("quantity", 0)) > 0:
			candidates.append(record)
	# A bounded sample, not original MMO population. Every point stays inside its
	# recovered spawn rectangle, with passability checks against the decoded map.
	for i in range(MAX_ENEMIES):
		if candidates.is_empty():
			break
		var source: Dictionary = candidates[i % candidates.size()]
		var bounds: Dictionary = source.get("bounds", {})
		var left: int = clampi(int(bounds.get("left", 0)), 0, width - 1)
		var top: int = clampi(int(bounds.get("top", 0)), 0, height - 1)
		var right: int = clampi(int(bounds.get("right", width - 1)), left, width - 1)
		var bottom: int = clampi(int(bounds.get("bottom", height - 1)), top, height - 1)
		var found: bool = false
		var pos := Vector2.ZERO
		for attempt in range(180):
			if attempt < 100:
				var center: Vector2 = player + Vector2(random.randf_range(-15.0, 15.0), random.randf_range(-15.0, 15.0))
				pos = Vector2(clampi(int(center.x), left, right) + 0.5, clampi(int(center.y), top, bottom) + 0.5)
			else:
				pos = Vector2(random.randi_range(left, right) + 0.5, random.randi_range(top, bottom) + 0.5)
			if can_stand(pos) and pos.distance_to(player) > 3.0:
				found = true
				break
		if not found:
			continue
		enemies.append({"monster_id": int(source.get("monster_id", 0)), "name": str(source.get("name", "")), "x": pos.x, "y": pos.y, "hp": 36, "max_hp": 36, "cooldown": random.randf_range(0.1, 1.5), "alive": true, "respawn_seconds": source.get("respawn_seconds",60), "respawn_timer": 0.0, "source": source.get("source", {})})

func tick(delta: float, direction: Vector2) -> void:
	if map_id < 0:
		return
	var dt: float = clampf(delta, 0.0, 0.1)
	elapsed += dt
	motion = direction
	if direction.length_squared() > 0.001:
		facing = facing_for(direction)
	attack_cooldown = maxf(0.0, attack_cooldown - dt)
	attack_flash = maxf(0.0, attack_flash - dt)
	if direction.length_squared() > 0.001:
		player = move_entity(player, direction.limit_length(1.0) * MOVE_SPEED * (1.6 if running else 1.0) * dt)
	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			enemy["respawn_timer"] = maxf(0, float(enemy.get("respawn_timer",60)) - dt)
			if float(enemy["respawn_timer"]) <= 0:
				enemy["alive"] = true
				enemy["hp"] = 36
			continue
		var position := Vector2(float(enemy["x"]), float(enemy["y"]))
		enemy["moving"] = false
		var distance: float = position.distance_to(player)
		enemy["cooldown"] = maxf(0.0, float(enemy["cooldown"]) - dt)
		if distance < 8.0 and distance > 1.35:
			var toward: Vector2 = position.direction_to(player)
			var moved: Vector2 = move_entity(position,toward * 1.1 * dt)
			if not clear_sight(position,player) and navigation != null:
				enemy["nav_cooldown"] = maxf(0,float(enemy.get("nav_cooldown",0))-dt)
				if float(enemy["nav_cooldown"]) <= 0:
					var path: Array[Vector2i] = navigation.get_id_path(Vector2i(position.floor()),Vector2i(player.floor()))
					if path.size()>1:
						enemy["nav_x"] = path[1].x+0.5
						enemy["nav_y"] = path[1].y+0.5
					enemy["nav_cooldown"] = 0.5
				var next := Vector2(float(enemy.get("nav_x",position.x)),float(enemy.get("nav_y",position.y)))
				toward = position.direction_to(next)
				moved = move_entity(position,toward*1.1*dt)
			position = moved
			enemy["facing"] = facing_for(toward)
			enemy["moving"] = true
			enemy["x"] = position.x
			enemy["y"] = position.y
		elif distance <= 1.6 and float(enemy["cooldown"]) <= 0.0 and clear_sight(position,player):
			hp = maxi(0, hp - maxi(1,4 - armor_bonus))
			enemy["cooldown"] = 1.4
	if hp <= 0:
		hp = PLAYER_HP
		player = find_start(current_map.get("start", [width / 2, height / 2]))
		message = "Recovered at the map start. Your progress is kept."

func move_entity(origin: Vector2, movement: Vector2) -> Vector2:
	# Substeps also make this safe for direct callers outside the fixed frame cap.
	var result: Vector2 = origin
	var steps: int = maxi(1, int(ceil(movement.length() / 0.2)))
	var step: Vector2 = movement / float(steps)
	for _i in range(steps):
		var x_next: Vector2 = result + Vector2(step.x, 0.0)
		if can_stand(x_next):
			result.x = x_next.x
		var y_next: Vector2 = result + Vector2(0.0, step.y)
		if can_stand(y_next):
			result.y = y_next.y
	return result

func attack() -> bool:
	if attack_cooldown > 0.0 or map_id < 0:
		return false
	attack_cooldown = 0.45
	attack_flash = 0.18
	var target: Dictionary = {}
	var best: float = 2.8
	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var distance: float = player.distance_to(Vector2(float(enemy["x"]), float(enemy["y"])))
		if distance < best and clear_sight(player,Vector2(float(enemy["x"]),float(enemy["y"]))):
			best = distance
			target = enemy
	if target.is_empty():
		message = "Move closer to a creature to attack."
		return false
	target["hp"] = maxi(0, int(target["hp"]) - 12 - weapon_bonus - (level - 1) * 2)
	if int(target["hp"]) <= 0:
		target["alive"] = false
		target["respawn_timer"] = maxf(1,float(target.get("respawn_seconds",60)))
		defeated += 1
		gold += 5
		for spawn in content.get("spawns", []):
			if int(spawn.get("monster_id",0)) == int(target["monster_id"]) and int(spawn.get("map_id",-1)) == map_id:
				var drops: Array = spawn.get("items", [])
				if not drops.is_empty():
					var key: String = "%d:%d" % [drops[0]["kind"], drops[0]["index"]]
					inventory[key] = int(inventory.get(key,0)) + 1
				break
		xp += 10
		if xp >= level * 40:
			xp -= level * 40
			level += 1
			hp = PLAYER_HP
			potions += 1
			message = "Level %d · health restored, one heal gained." % level
		else:
			message = "Creature %d defeated · +10 prototype XP" % int(target["monster_id"])
	else:
		message = "Hit creature %d" % int(target["monster_id"])
	return true

func heal() -> bool:
	if potions <= 0 or hp >= PLAYER_HP:
		message = "Healing available when injured and a heal remains."
		return false
	potions -= 1
	mana = mini(50, mana + 25)
	hp = mini(PLAYER_HP, hp + 45)
	message = "Health restored · %d heals remain" % potions
	return true

func remember_map() -> void:
	if map_id >= 0:
		map_states[str(map_id)] = {"player": [player.x, player.y], "enemies": enemies.duplicate(true)}

func restore_map_state(state: Dictionary) -> void:
	var position: Variant = state.get("player", [])
	if position is Array and position.size() == 2:
		var proposed := Vector2(float(position[0]), float(position[1]))
		if proposed.is_finite() and can_stand(proposed):
			player = proposed
	var previous: Variant = state.get("enemies", [])
	if previous is Array:
		for candidate in previous.slice(0, MAX_ENEMIES):
			if not candidate is Dictionary:
				continue
			var proposed := Vector2(float(candidate.get("x", -1)), float(candidate.get("y", -1)))
			if not proposed.is_finite() or not can_stand(proposed):
				continue
			enemies.append({"monster_id": int(candidate.get("monster_id", 0)), "name": str(candidate.get("name", "")), "x": proposed.x, "y": proposed.y, "hp": clampi(int(candidate.get("hp", 36)), 0, 36), "max_hp": 36, "cooldown": 1.0, "alive": bool(candidate.get("alive", true)), "respawn_seconds": maxf(1,float(candidate.get("respawn_seconds",60))), "respawn_timer": maxf(0,float(candidate.get("respawn_timer",60))), "source": candidate.get("source", {})})

func save_game(path: String = "user://progress.json") -> Error:
	remember_map()
	var record: Dictionary = {"version": SAVE_VERSION, "map_id": map_id, "hp": hp, "xp": xp, "level": level, "potions": potions, "defeated": defeated, "map_states": map_states, "purchases":purchases,"facing":facing,"armor_bonus":armor_bonus,"gold":gold,"inventory":inventory,"weapon_bonus":weapon_bonus,"character_id":character_id,"mana":mana,"bounty_claimed":bounty_claimed}
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(record))
	file.flush()
	file.close()
	if FileAccess.file_exists(path) and valid_save(read_json(path)):
		DirAccess.copy_absolute(path,path+".bak")
	var result: Error = DirAccess.rename_absolute(temporary, path)
	if result == OK:
		message = "Progress saved on this device."
	return result

func load_game(path: String = "user://progress.json") -> bool:
	var saved: Variant = read_json(path)
	if not valid_save(saved):
		saved = read_json(path+".bak")
		if not valid_save(saved):
			return false
	var prior_states: Dictionary = map_states
	map_states = saved["map_states"]
	if not enter_map(int(saved.get("map_id", -1)), false):
		map_states = prior_states
		return false
	hp = clampi(int(saved.get("hp", PLAYER_HP)), 1, PLAYER_HP)
	level = clampi(int(saved.get("level", 1)), 1, 1000)
	xp = clampi(int(saved.get("xp", 0)), 0, level * 40 - 1)
	potions = clampi(int(saved.get("potions", 5)), 0, 9999)
	defeated = maxi(0, int(saved.get("defeated", 0)))
	armor_bonus = clampi(int(saved.get("armor_bonus",0)),0,3)
	gold = clampi(int(saved.get("gold",0)),0,99999999)
	weapon_bonus = clampi(int(saved.get("weapon_bonus",0)),0,50)
	character_id = clampi(int(saved.get("character_id",1)),0,9)
	mana = clampi(int(saved.get("mana",50)),0,50)
	bounty_claimed = bool(saved.get("bounty_claimed",false))
	if saved.get("inventory",{}) is Dictionary:
		inventory = saved.get("inventory",{}).duplicate()
		for key in inventory:
			inventory[key] = int(inventory[key])
	purchases = saved.get("purchases",{}).duplicate()
	for key in purchases:
		purchases[key] = int(purchases[key])
	facing = int(saved.get("facing",6))
	message = "Local progress restored."
	return true

func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func valid_save(saved: Variant) -> bool:
	if not saved is Dictionary or not valid_number(saved.get("version")) or int(saved["version"]) != SAVE_VERSION:
		return false
	for key in ["map_id", "hp", "xp", "level", "potions", "defeated"]:
		if not valid_number(saved.get(key)):
			return false
	for key in ["gold","armor_bonus","weapon_bonus","character_id","mana","facing"]:
		if saved.has(key) and not valid_number(saved[key]):
			return false
	for key in ["inventory","purchases"]:
		var bag: Variant = saved.get(key,{})
		if not bag is Dictionary or bag.size()>10000:
			return false
		for value in bag.values():
			if not valid_number(value) or float(value)<0 or float(value)>4000000001:
				return false
	var states: Variant = saved.get("map_states")
	if not states is Dictionary or states.size() > catalog.size():
		return false
	for state in states.values():
		if not state is Dictionary:
			return false
		var position: Variant = state.get("player")
		if not position is Array or position.size() != 2 or not valid_number(position[0]) or not valid_number(position[1]):
			return false
		var creatures: Variant = state.get("enemies")
		if not creatures is Array or creatures.size() > MAX_ENEMIES:
			return false
		for creature in creatures:
			if not creature is Dictionary:
				return false
			for key in ["monster_id", "x", "y", "hp"]:
				if not valid_number(creature.get(key)):
					return false
			if not creature.get("alive") is bool:
				return false
	return true

func reset_progress(path: String = "user://progress.json") -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	map_states = {}
	gold = 0
	inventory = {}
	purchases = {}
	weapon_bonus = 0
	armor_bonus = 0
	bounty_claimed = false
	mana = 50
	hp = PLAYER_HP
	xp = 0
	level = 1
	potions = 5
	defeated = 0
	enter_map(map_id, false)
	message = "Prototype progress reset."

func appearance(monster_id: int) -> int:
	for monster in content.get("monsters", []):
		if int(monster["id"]) == monster_id:
			return int(monster["appearance_id"])
	return 1

func item_name(key: String) -> String:
	return str(item_tables.get(key, "Recovered item " + key))

func use_item(key: String) -> void:
	if int(inventory.get(key,0)) <= 0:
		return
	if key.begins_with("1:"):
		weapon_bonus = 6
		message = "Weapon equipped: " + item_name(key)
	elif key.begins_with("2:") or key.begins_with("3:"):
		armor_bonus = 2
		message = "Armor equipped: " + item_name(key)
	elif key.begins_with("4:"):
		hp = mini(PLAYER_HP, hp + 25)
		inventory[key] -= 1
		message = "Used " + item_name(key)
	else:
		message = "This item effect has not been reconstructed yet."
	save_game()

func cast_skill() -> bool:
	if mana < 20:
		message = "Not enough mana. Rest by using a heal."
		return false
	mana -= 20
	attack_cooldown = 0.0
	var prior: int = weapon_bonus
	weapon_bonus += 24
	var hit: bool = attack()
	weapon_bonus = prior
	return hit

func interact() -> void:
	shop_available = false
	for npc in content.get("npcs", []):
		if int(npc.get("map_id",-1)) != map_id:
			continue
		var b: Dictionary = npc["bounds"]
		var pos := Vector2((float(b["left"])+float(b["right"]))*0.5, (float(b["top"])+float(b["bottom"]))*0.5)
		if pos.distance_to(player) < 8:
			message = str(npc["name"]) + ": Welcome, traveler."
			for link in content.get("map_shops", []):
				if int(link.get("map_id",-1)) == map_id:
					shop_available = true
			return
	message = "Move within 8 tiles of an NPC to talk."

func buy_heal() -> void:
	if shop_available and gold >= 15:
		gold -= 15
		potions += 1
		save_game()

func sell_item(key: String) -> void:
	if shop_available and int(inventory.get(key,0)) > 0:
		inventory[key] -= 1
		gold += 5
		save_game()

func claim_bounty() -> void:
	if defeated >= 10 and not bounty_claimed:
		gold += 100
		potions += 3
		bounty_claimed = true
		message = "Offline bounty complete."
		save_game()
	else:
		message = "Bounty requires 10 defeats and can be claimed once."

func facing_for(direction: Vector2) -> int:
	var x: int = int(signf(direction.x)) if absf(direction.x)>0.2 else 0
	var y: int = int(signf(direction.y)) if absf(direction.y)>0.2 else 0
	if x==0 and y==0:
		return facing
	return 5+x-y*3

func clear_sight(start: Vector2, finish: Vector2) -> bool:
	var steps: int = maxi(1,int(ceil(start.distance_to(finish)*4)))
	for i in range(steps+1):
		if not is_open(Vector2i(start.lerp(finish,float(i)/steps).floor())):
			return false
	return true

func use_exit() -> bool:
	var pixel: Vector2 = player*Vector2(48,24)
	for exit in exits.get(str(map_id),[]):
		var rect := Rect2(float(exit["left"]),float(exit["top"]),float(exit["right"])-float(exit["left"]),float(exit["bottom"])-float(exit["top"]))
		if not rect.grow(48).has_point(pixel):
			continue
		for event in content.get("events",[]):
			if int(event.get("map_id",-1)) != map_id or int(event.get("id",-1)) != int(exit["id"]) or int(event.get("type",-1)) != 1:
				continue
			var args: Array = event.get("args",[])
			if args.size()<4:
				continue
			if enter_map(int(args[0])):
				player = find_start([int(args[1]),int(args[2])])
				message = "Travelled through the recovered map exit."
				save_game()
				return true
	message = "No supported exit nearby. Blue EXIT markers identify client event locations."
	return false

func zone_stock() -> Array:
	var shop_ids: Dictionary = {}
	for link in content.get("map_shops",[]):
		if int(link.get("map_id",-1))==map_id:
			shop_ids[int(link["shop_id"])]=true
	var stock: Array = []
	for item in content.get("shops",[]):
		if not shop_ids.has(int(item["shop_id"])) or int(item["kind"]) not in [1,2,3,4]:
			continue
		var key: String = "%d:%d" % [item["kind"],item["index"]]
		var purchase_key: String = "%d:%s" % [item["shop_id"],key]
		if int(item["count"])<=int(purchases.get(purchase_key,0)):
			continue
		var base: int = 100 if int(item["kind"])==1 else (80 if int(item["kind"]) in [2,3] else 10)
		stock.append({"key":key,"purchase_key":purchase_key,"name":item_name(key),"price":maxi(1,int(base*int(item["price_percent"])/100)),"count":int(item["count"])})
	return stock

func buy_stock(purchase_key: String) -> bool:
	for item in zone_stock():
		if item["purchase_key"]!=purchase_key:
			continue
		if gold<int(item["price"]):
			message = "Not enough gold."
			return false
		gold-=int(item["price"])
		inventory[item["key"]]=int(inventory.get(item["key"],0))+1
		purchases[purchase_key]=int(purchases.get(purchase_key,0))+1
		message = "Bought "+str(item["name"])
		save_game()
		return true
	return false

func map_exit_rectangles() -> Array:
	if exit_marker_cache.has(map_id):
		return exit_marker_cache[map_id]
	var ids: Dictionary={}
	for event in content.get("events",[]):
		if int(event.get("map_id",-1))==map_id and int(event["type"])==1:
			ids[int(event["id"])]=true
	var markers: Array=[]
	for rect in exits.get(str(map_id),[]):
		if ids.has(int(rect["id"])):
			markers.append(rect)
	exit_marker_cache[map_id]=markers
	return markers
