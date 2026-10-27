extends RefCounted
## Deterministic offline sandbox. Content IDs and placement bounds are recovered;
## movement speed, HP, damage, XP progression and AI are provisional game rules.

const SAVE_VERSION: int = 1
const MOVE_SPEED: float = 5.0
const BASE_POWER: int = 90
# Recovered InitializeHPMax: 50 + floor(P/15)*floor(P/10).
const PLAYER_HP: int = 50 + (BASE_POWER / 15) * (BASE_POWER / 10)
const MAX_ENEMIES: int = 18

var player_name: String = "Traveler"
var journey: Dictionary = {}
var adventure_started: bool = false
var tutorial_stage: int = 0
var tutorial_kills: int = 0
var visited: Array = []
var bank_gold: int = 0
var arrival_grace: float = 0.0
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
const HERO_NAMES: Array = ["Philar","Azlar","Sadad","Destino","Jarexx","Canon","Lunarena","Kitara","Lavita"]
var item_metadata: Dictionary = {}
var equipment: Dictionary = {}
var stats: Dictionary = {"strength":90,"spirit":90,"dexterity":90,"power":90}
var bonus_points: int = 0
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
	var journey_data = read_json(data_root+"/journey.json")
	if journey_data is Dictionary:
		journey = journey_data
	var portal_data = read_json(data_root + "/client-events.json")
	if portal_data is Dictionary:
		exits = portal_data
	var binary = read_json(data_root + "/binary-content.json")
	if binary is Dictionary:
		for table in binary.get("tables", []):
			if table.get("kind") == "items":
				for item in table.get("records", []):
					item_tables["%d:%d" % [int(table.get("category",0)), int(item.get("slot",0))]] = item.get("name", "Item")
	var metadata = read_json(data_root + "/item-metadata.json")
	if metadata is Dictionary:
		item_metadata = metadata.get("items",{})
		for key in item_metadata:
			item_tables[key] = item_metadata[key]["name"]
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
	shop_available=false
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
	if adventure_started:
		if not visited.has(id): visited.append(id)
		if tutorial_stage==1 and id==1: tutorial_stage=2
	message = map_name(id)
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
	if adventure_started:
		candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return spawn_distance(a)<spawn_distance(b))
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
	arrival_grace=maxf(0,arrival_grace-dt)
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
		elif distance <= 1.6 and float(enemy["cooldown"]) <= 0.0 and clear_sight(position,player) and arrival_grace<=0:
			hp = maxi(0, hp - maxi(1,4 - armor_bonus))
			enemy["cooldown"] = 1.4
	if hp <= 0 and adventure_started:
		enter_map(9)
		player=find_start([9,12])
		hp=max_hp()
		mana=max_mana()
		message="You recovered at Street 1 Hospital. Your belongings are safe."
	elif hp <= 0:
		hp = max_hp()
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
	var best: float = weapon_range()
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
		if adventure_started and tutorial_stage==2 and map_id==0:
			tutorial_kills+=1
			if tutorial_kills>=3: tutorial_stage=3
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
			bonus_points += 3 if level%100==0 else 2
			hp = max_hp()
			potions += 1
			message = "Level %d · +%d stat points. Open BAG → CHARACTER." % [level,3 if level%100==0 else 2]
		else:
			message = "Creature %d defeated · +10 prototype XP" % int(target["monster_id"])
	else:
		message = "Hit creature %d" % int(target["monster_id"])
	return true

func heal() -> bool:
	if potions <= 0 or hp >= max_hp():
		message = "Healing available when injured and a heal remains."
		return false
	potions -= 1
	mana = mini(max_mana(), mana + 25)
	hp = mini(max_hp(), hp + 45)
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
	var record: Dictionary = {"player_name":player_name,"adventure_started":adventure_started,"tutorial_stage":tutorial_stage,"tutorial_kills":tutorial_kills,"visited":visited,"bank_gold":bank_gold,"version": SAVE_VERSION, "map_id": map_id, "hp": hp, "xp": xp, "level": level, "potions": potions, "defeated": defeated, "map_states": map_states, "stats":stats,"bonus_points":bonus_points,"equipment":equipment,"purchases":purchases,"facing":facing,"armor_bonus":armor_bonus,"gold":gold,"inventory":inventory,"weapon_bonus":weapon_bonus,"character_id":character_id,"mana":mana,"bounty_claimed":bounty_claimed}
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
	return result

func load_game(path: String = "user://progress.json") -> bool:
	var saved: Variant = read_json(path)
	if not valid_save(saved):
		saved = read_json(path+".bak")
		if not valid_save(saved):
			return false
	player_name=str(saved.get("player_name","Traveler"))
	adventure_started=bool(saved.get("adventure_started",false))
	tutorial_stage=clampi(int(saved.get("tutorial_stage",0)),0,4)
	tutorial_kills=clampi(int(saved.get("tutorial_kills",0)),0,3)
	visited=[]
	for id in saved.get("visited",[]): visited.append(int(id))
	bank_gold=clampi(int(saved.get("bank_gold",0)),0,99999999)
	var prior_states: Dictionary = map_states
	map_states = saved["map_states"]
	if not enter_map(int(saved.get("map_id", -1)), false):
		map_states = prior_states
		return false
	stats = saved.get("stats",{"strength":90,"spirit":90,"dexterity":90,"power":90}).duplicate()
	for key in stats:
		stats[key]=int(stats[key])
	equipment=saved.get("equipment",{}).duplicate()
	hp = clampi(int(saved.get("hp", PLAYER_HP)), 1, max_hp())
	level = clampi(int(saved.get("level", 1)), 1, 1000)
	bonus_points=maxi(0,int(saved.get("bonus_points",2*(level-1)+level/100)))
	xp = clampi(int(saved.get("xp", 0)), 0, level * 40 - 1)
	potions = clampi(int(saved.get("potions", 5)), 0, 9999)
	defeated = maxi(0, int(saved.get("defeated", 0)))
	armor_bonus = clampi(int(saved.get("armor_bonus",0)),0,3)
	gold = clampi(int(saved.get("gold",0)),0,99999999)
	weapon_bonus = clampi(int(saved.get("weapon_bonus",0)),0,50)
	character_id = clampi(int(saved.get("character_id",1)),0,8)
	mana = clampi(int(saved.get("mana",50)),0,max_mana())
	bounty_claimed = bool(saved.get("bounty_claimed",false))
	if saved.get("inventory",{}) is Dictionary:
		inventory = saved.get("inventory",{}).duplicate()
		for key in inventory:
			inventory[key] = int(inventory[key])
	equipment = saved.get("equipment",{}).duplicate()
	if not equipment.is_empty():
		refresh_equipment()
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
	for key in ["tutorial_stage","tutorial_kills","bank_gold","gold","armor_bonus","weapon_bonus","character_id","mana","facing","bonus_points"]:
		if saved.has(key) and not valid_number(saved[key]):
			return false
	for key in ["inventory","purchases"]:
		var bag: Variant = saved.get(key,{})
		if not bag is Dictionary or bag.size()>10000:
			return false
		for value in bag.values():
			if not valid_number(value) or float(value)<0 or float(value)>4000000001:
				return false
	var attributes: Variant=saved.get("stats",{"strength":90,"spirit":90,"dexterity":90,"power":90})
	if not attributes is Dictionary:
		return false
	for attribute in ["strength","spirit","dexterity","power"]:
		if not valid_number(attributes.get(attribute)) or float(attributes[attribute])<0 or float(attributes[attribute])>4294967295:
			return false
	var gear: Variant = saved.get("equipment",{})
	if not gear is Dictionary or gear.size()>32:
		return false
	for key in gear:
		if not gear[key] is String:
			return false
	if saved.has("player_name") and (not saved["player_name"] is String or saved["player_name"].length()>24): return false
	if saved.has("adventure_started") and not saved["adventure_started"] is bool: return false
	var seen: Variant=saved.get("visited",[])
	if not seen is Array or seen.size()>catalog.size(): return false
	for id in seen:
		if not valid_number(id): return false
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
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	map_states = {}
	adventure_started=false
	player_name="Traveler"
	tutorial_stage=0
	tutorial_kills=0
	visited=[]
	bank_gold=0
	gold = 0
	inventory = {}
	purchases = {}
	equipment = {}
	stats={"strength":90,"spirit":90,"dexterity":90,"power":90}
	bonus_points=0
	weapon_bonus = 0
	armor_bonus = 0
	bounty_claimed = false
	mana = 50
	hp = max_hp()
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
	if int(inventory.get(key,0))<=0:
		return
	var item: Dictionary=item_metadata.get(key,{})
	if item.is_empty():
		message="This item effect has not been reconstructed yet."
		return
	if key.begins_with("4:"):
		var health: int=int(item.get("hp",0))
		var energy: int=int(item.get("mp",0))
		if health==0 and energy==0:
			message="This item's special effect is not implemented."
			return
		if (health==0 or hp>=max_hp()) and (energy==0 or mana>=max_mana()):
			message="Health and mana are already full."
			return
		hp=mini(max_hp(),hp+health)
		mana=mini(max_mana(),mana+energy)
		inventory[key]-=1
		message="Used "+item_name(key)
	elif key.split(":")[0] in ["1","2","3"]:
		if level<int(item.get("required_level",0)):
			message="Requires level %d." % int(item["required_level"])
			return
		var mask: int=int(item.get("characters",0))
		if mask!=0 and (mask & (1<<character_id))==0:
			message="This item cannot be equipped by "+HERO_NAMES[character_id]+"."
			return
		for stat in ["strength","spirit","dexterity","power"]:
			if int(item.get("required_"+stat,0))>effective_stat(stat):
				message="Requires %s %d." % [stat,int(item["required_"+stat])]
				return
		equipment[str(int(item["slot"]))]=key
		refresh_equipment()
		message="Equipped "+item_name(key)
	else:
		message="This item effect has not been reconstructed yet."
	save_game()

func refresh_equipment() -> void:
	weapon_bonus=0
	armor_bonus=0
	for slot in equipment.keys():
		var key: String=equipment[slot]
		var item: Dictionary=item_metadata.get(key,{})
		var mask: int=int(item.get("characters",0))
		if item.is_empty() or int(inventory.get(key,0))<=0 or (mask!=0 and (mask & (1<<character_id))==0):
			equipment.erase(slot)
			continue
		weapon_bonus+=int(item.get("attack",0))
		armor_bonus+=int(item.get("defense",0))
	hp=mini(hp,max_hp())
	mana=mini(mana,max_mana())

func weapon_range() -> float:
	var result: float=1.8
	for key in equipment.values():
		if str(key).begins_with("1:"):
			result=maxf(result,float(item_metadata.get(key,{}).get("range",1))+0.5)
	return result

func item_details(key: String) -> String:
	var item: Dictionary=item_metadata.get(key,{})
	if item.is_empty():
		return "Effect unknown"
	return "ATK %d  DEF %d  HP +%d  MP +%d  Lv %d  Price %d" % [item.get("attack",0),item.get("defense",0),item.get("hp",0),item.get("mp",0),item.get("required_level",0),item.get("price",0)]

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

func npc_position(npc: Dictionary) -> Vector2:
	var b: Dictionary=npc.get("bounds",{})
	return Vector2((float(b.get("left",0))+float(b.get("right",0)))*0.5,(float(b.get("top",0))+float(b.get("bottom",0)))*0.5)

func nearest_npc() -> Dictionary:
	var nearest: Dictionary={}
	var distance: float=8.0
	for npc in content.get("npcs",[]):
		if int(npc.get("map_id",-1))!=map_id: continue
		var delta: float=npc_position(npc).distance_to(player)
		if delta<distance: distance=delta;nearest=npc
	return nearest

func npc_has_shop(npc: Dictionary) -> bool:
	var name: String=str(npc.get("name","")).to_lower()
	var merchant: bool=false
	for role in ["vendor","store","merchant","shop","trader","armorer"]:
		if role in name:merchant=true
	if not merchant or int(npc.get("map_id",-1))!=map_id:return false
	for link in content.get("map_shops",[]):
		if int(link.get("map_id",-1))==map_id:return true
	return false

func interact_with(npc: Dictionary) -> bool:
	shop_available=false
	if int(npc.get("map_id",-1))!=map_id or npc_position(npc).distance_to(player)>=8:
		message="Move closer to speak with this person."
		return false
	var name: String=str(npc.get("name","Traveler")).trim_prefix("+")
	message=name+": Welcome, "+player_name+"."
	if adventure_started and map_id==9 and name=="Doctor":
		doctor_service();return true
	shop_available=npc_has_shop(npc)
	return true

func interact() -> void:
	var npc:=nearest_npc()
	if npc.is_empty():
		shop_available=false;message="Move within 8 tiles of an NPC to talk."
	else: interact_with(npc)

func buy_heal() -> void:
	if shop_available and gold >= 15:
		gold -= 15
		potions += 1
		save_game()

func sell_item(key: String) -> void:
	if shop_available and int(inventory.get(key,0)) > 0:
		inventory[key] -= 1
		gold += maxi(0,int(item_metadata.get(key,{}).get("price",10))/2)
		refresh_equipment()
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
		stock.append({"key":key,"purchase_key":purchase_key,"name":item_name(key),"price":maxi(0,int(int(item_metadata.get(key,{}).get("price",base))*int(item["price_percent"])/100)),"count":int(item["count"])})
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

func effective_stat(attribute: String) -> int:
	var value: int=int(stats.get(attribute,90))
	for key in equipment.values():
		value+=int(item_metadata.get(key,{}).get(attribute,0))
	return value & 0xffffffff

func hp_for(power: int) -> int:
	return maxi(1,(50+(power/15)*(power/10)) & 0xffffffff)

func mana_for(spirit: int) -> int:
	if spirit<=20000: return maxi(1,(50+(spirit/15)*(spirit/10)) & 0xffffffff)
	return maxi(1,(273*spirit-0x2a9df6) & 0xffffffff)

func max_hp() -> int: return hp_for(effective_stat("power"))
func max_mana() -> int: return mana_for(effective_stat("spirit"))

func allocate_stats(changes: Dictionary, path: String="user://progress.json") -> bool:
	var total: int=0
	for key in changes:
		var value: Variant=changes[key]
		if not stats.has(key) or not valid_number(value) or float(value)<0 or float(value)!=floor(float(value)) or float(value)>bonus_points: return false
		if int(stats[key])+int(value)>4294967295: return false
		total+=int(value)
	if total<=0 or total>bonus_points: return false
	var before:=stats.duplicate();var points: int=bonus_points
	for key in changes: stats[key]=int(stats[key])+int(changes[key])
	bonus_points-=total
	if save_game(path)!=OK:
		stats=before;bonus_points=points;message="Could not save stat changes. Points were kept.";return false
	message="Attributes increased. %d points remaining." % bonus_points
	return true

func allocate_stat(attribute: String) -> bool:
	if bonus_points<=0 or not stats.has(attribute):
		return false
	stats[attribute]=int(stats[attribute])+1
	bonus_points-=1
	save_game()
	return true


func map_name(id: int = -1) -> String:
	var key: int=map_id if id<0 else id
	return str(journey.get("map_names",{}).get(str(key),"Zone %05d" % key))

func create_character(chosen_name: String, hero: int, path: String="user://progress.json") -> bool:
	var clean: String=chosen_name.strip_edges()
	if clean.length()<2 or clean.length()>14 or hero<0 or hero>=HERO_NAMES.size():
		message="Choose a name of 2–14 characters."
		return false
	for index in range(clean.length()):
		if clean.unicode_at(index)<32: return false
	# Preserve the previous save/backup until the new adventure is saved atomically.
	map_states={};inventory={"4:1":5,"5:93":1,"5:94":1,"5:95":1};equipment={};purchases={}
	stats={"strength":10,"spirit":10,"dexterity":10,"power":10}
	bonus_points=0;level=1;xp=0;gold=0;bank_gold=0;defeated=0;potions=5
	weapon_bonus=0;armor_bonus=0;bounty_claimed=false;character_id=hero;player_name=clean
	adventure_started=true;tutorial_stage=0;tutorial_kills=0;visited=[]
	if not enter_map(9,false): return false
	player=find_start([9,12]);hp=max_hp();mana=max_mana()
	message="Welcome, "+player_name+". Speak with the Doctor to begin."
	return save_game(path)==OK

func objective() -> String:
	if not adventure_started: return "Explore recovered maps. Start a new character from MENU for the guided adventure."
	return ["Speak with the Doctor here at Street 1 Hospital.","Visit Street 1 using TRAVEL, then head to the Backyard.","Backyard training: defeat 3 creatures (%d/3)." % tutorial_kills,"Return to Street 1 Hospital and speak with the Doctor.","Training complete. Explore towns, improve equipment and follow recovered exits."][tutorial_stage]

func doctor_service() -> void:
	hp=max_hp();mana=max_mana()
	if tutorial_stage==0:
		tutorial_stage=1
		inventory["2:1"]=int(inventory.get("2:1",0))+1
		use_item("2:1")
		var cheapest: String=""
		var price: int=2147483647
		for key in item_metadata:
			var item: Dictionary=item_metadata[key]
			if not str(key).begins_with("1:") or int(item.get("required_level",99))>1 or int(item.get("attack",0))<=0: continue
			if (int(item.get("characters",0)) & (1<<character_id))==0: continue
			var eligible: bool=true
			for stat in stats:
				if int(item.get("required_"+stat,0))>effective_stat(stat): eligible=false
			if eligible and int(item.get("price",0))<price:
				cheapest=key;price=int(item.get("price",0))
		if not cheapest.is_empty():
			inventory[cheapest]=int(inventory.get(cheapest,0))+1
			use_item(cheapest)
		gold+=50
		message="Doctor: Take these supplies. Visit Street 1, then train in the Backyard."
	elif tutorial_stage==3:
		tutorial_stage=4;gold+=100;inventory["4:1"]=int(inventory.get("4:1",0))+3
		message="Doctor: Training complete! Reward: 100 gold and 3 food. Explore the town shops."
	else:
		message="Doctor: Your health and mana are restored. "+objective()
	save_game()

func travel_options() -> Array:
	var options: Array=[]
	var links: Dictionary=journey.get("links",{}).get(str(map_id),{})
	for key in links:
		options.append(int(key))
	# The beginner guide offers return trips between starter services.
	if adventure_started:
		for id in [0,1,4,5,9,10]:
			if not options.has(id): options.append(id)
	options.sort()
	return options

func travel_to(id: int) -> bool:
	if not travel_options().has(id):
		message="Reach this destination through a connected exit first."
		return false
	var first_visit: bool=not visited.has(id)
	var target: Variant=journey.get("links",{}).get(str(map_id),{}).get(str(id))
	if not enter_map(id): return false
	if id in [4,5,9,10]:
		player=find_start([9,12])
	elif target is Array:
		player=find_start(target)
	elif id==1:
		player=find_start([122,115])
	if first_visit:
		enemies=[]
		spawn_enemies()
	arrival_grace=5.0
	message="Arrived at "+map_name()+". "+objective()
	save_game()
	return true

func deposit_gold() -> bool:
	if map_id!=4 or gold<=0: return false
	bank_gold+=gold;gold=0;save_game();return true

func withdraw_gold() -> bool:
	if map_id!=4 or bank_gold<=0: return false
	gold+=bank_gold;bank_gold=0;save_game();return true


func spawn_distance(record: Dictionary) -> float:
	var bounds: Dictionary=record.get("bounds",{})
	var closest:=Vector2(clampf(player.x,float(bounds.get("left",0)),float(bounds.get("right",width-1))),clampf(player.y,float(bounds.get("top",0)),float(bounds.get("bottom",height-1))))
	return closest.distance_squared_to(player)
