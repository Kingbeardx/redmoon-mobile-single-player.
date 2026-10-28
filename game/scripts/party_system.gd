extends RefCounted
## Reconstructed single-player allies and shared support-skill targets.
var owner_ref: WeakRef
var world:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var allies: Array=[]
var remote_allies: Array=[]
var selected: int=0
var portal: Dictionary={}
var destination: int=9
func setup(w) -> void:owner_ref=weakref(w)
func recruit(hero: int) -> bool:
	if world.request_online("recruit",hero):return true
	if hero<0 or hero>8 or allies.size()>=2:return false
	var hp: int=maxi(100,world.max_hp())
	allies.append({"hero":hero,"name":world.HERO_NAMES[hero],"hp":hp,"max_hp":hp,"x":world.player.x,"y":world.player.y,"cooldown":0.0,"appearance":world.server_hero(hero),"map":world.map_id});return true
func targets() -> Array:return allies+remote_allies
func target(dead: bool=false) -> Dictionary:
	var choices: Array=targets()
	if selected>=0 and selected<choices.size() and (int(choices[selected]["hp"])<=0)==dead:return choices[selected]
	for ally in choices:
		if (int(ally["hp"])<=0)==dead:return ally
	return {}
func regroup() -> void:
	if world.request_online("rally"):return
	for ally in allies:
		ally["map"]=world.map_id;ally["x"]=world.player.x;ally["y"]=world.player.y
func tick(delta: float) -> void:
	if world==null:return
	if not portal.is_empty() and float(portal["until"])<=Time.get_unix_time_from_system():portal.clear()
	for ally in allies:
		var maximum: int=maxi(100,world.hp_for(int(world.stats.get("power",10))))
		if maximum!=int(ally["max_hp"]):
			ally["hp"]=clampi(roundi(float(ally["hp"])*maximum/maxi(1,int(ally["max_hp"]))),0,maximum);ally["max_hp"]=maximum
		if int(ally["hp"])<=0:continue
		var pos:=Vector2(ally["x"],ally["y"])
		if int(ally["map"])!=world.map_id:continue
		ally["cooldown"]=maxf(0,float(ally["cooldown"])-delta)
		var movement: Vector2=Vector2.ZERO
		if pos.distance_to(world.player)>3:movement=pos.direction_to(world.player)*world.MOVE_SPEED*delta
		elif float(ally["cooldown"])<=0:
			for enemy in world.enemies:
				var ep:=Vector2(enemy["x"],enemy["y"])
				if bool(enemy.get("alive",false)) and pos.distance_to(ep)<4 and world.clear_sight(pos,ep):
					if pos.distance_to(ep)>1.5:movement=pos.direction_to(ep)*3*delta
					else:
						world.damage_enemy(enemy,maxi(8,world.basic_attack_power()/2));ally["cooldown"]=.9;ally["action_remaining"]=.55;ally["facing"]=world.facing_for(pos.direction_to(ep))
					break
		if pos.distance_to(world.player)>15:pos=world.player
		else:pos=world.move_entity(pos,movement)
		ally["moving"]=movement.length_squared()>.0001
		if movement.length_squared()>.0001:ally["facing"]=world.facing_for(movement)
		ally["x"]=pos.x;ally["y"]=pos.y
		ally["action_remaining"]=maxf(0,float(ally.get("action_remaining",0))-delta)
func intercept(attacker: Dictionary,damage: int) -> bool:
	if attacker.is_empty():return false
	var enemy_pos:=Vector2(attacker.get("x",0),attacker.get("y",0))
	for ally in allies:
		if int(ally["hp"])<=0 or int(ally["map"])!=world.map_id:continue
		var pos:=Vector2(ally["x"],ally["y"])
		if enemy_pos.distance_to(pos)<minf(2,enemy_pos.distance_to(world.player)):
			ally["hp"]=maxi(0,int(ally["hp"])-damage);return true
	return false
func prepare(mode: String) -> String:
	if mode=="gate" and destination==world.map_id:return "Choose a different gate destination in PARTY."
	if mode=="gate":return "Ready" if world.catalog.any(func(row:Dictionary)->bool:return int(row["id"])==destination) else "Choose an available gate destination in PARTY."
	var ally: Dictionary=target(mode=="resurrect")
	if ally.is_empty():return "Recruit an ally in JOURNEY → PARTY." if mode!="resurrect" else "No fallen ally to resurrect."
	if int(ally["map"])!=world.map_id:return "Your ally is in another area."
	if mode=="resurrect" and (world.player.distance_to(Vector2(ally["x"],ally["y"]))>1.5 or world.hp<2):return "Stand beside the fallen ally with at least 2 HP."
	return "Ready"
func support(mode: String) -> void:
	var ally: Dictionary=target(mode=="resurrect")
	match mode:
		"gate":portal={"map":world.map_id,"x":world.player.x,"y":world.player.y,"destination":destination,"until":Time.get_unix_time_from_system()+60}
		"recall":ally["x"]=world.player.x;ally["y"]=world.player.y
		"ally_teleport":world.player=world.find_start([int(ally["x"]),int(ally["y"])])
		"resurrect":
			var gift: int=maxi(1,world.hp/2);world.hp-=gift;ally["hp"]=mini(int(ally["max_hp"]),gift)
func use_gate() -> bool:
	if portal.is_empty() or float(portal["until"])<=Time.get_unix_time_from_system():return false
	var at_origin: bool=world.map_id==int(portal["map"])
	if at_origin and world.player.distance_to(Vector2(portal["x"],portal["y"]))>3:return false
	if not at_origin and world.map_id!=int(portal["destination"]):return false
	var travel: int=int(portal["destination"]) if at_origin else int(portal["map"])
	if not world.enter_map(travel):return false
	if not at_origin:world.player=world.find_start([int(portal["x"]),int(portal["y"])])
	regroup();return true
func serialize() -> Dictionary:return {"allies":allies.duplicate(true),"selected":selected,"destination":destination,"portal":portal.duplicate(true)}
func restore(saved: Variant) -> void:
	allies=[];portal={};selected=0;destination=9
	if not saved is Dictionary:return
	var rows: Variant=saved.get("allies",[])
	if rows is Array:
		for row in rows.slice(0,2):
			if not row is Dictionary:continue
			var valid: bool=true
			for key in ["hero","hp","max_hp","x","y","map"]:
				if not world.valid_number(row.get(key)):valid=false
			if not valid or int(row["hero"])<0 or int(row["hero"])>8:continue
			var h: int=int(row["hero"]);var maximum: int=clampi(int(row["max_hp"]),1,100000000)
			allies.append({"hero":h,"name":world.HERO_NAMES[h],"hp":clampi(int(row["hp"]),0,maximum),"max_hp":maximum,"x":float(row["x"]),"y":float(row["y"]),"map":int(row["map"]),"cooldown":0.0,"appearance":world.server_hero(h)})
	if world.valid_number(saved.get("selected")):selected=clampi(int(saved["selected"]),0,4)
	if world.valid_number(saved.get("destination")):destination=int(saved["destination"])
	var gate: Variant=saved.get("portal",{})
	if gate is Dictionary and ["map","x","y","destination","until"].all(func(k:String)->bool:return world.valid_number(gate.get(k))):
		if float(gate["until"])>Time.get_unix_time_from_system() and float(gate["until"])<Time.get_unix_time_from_system()+61:portal=gate.duplicate()

func dismiss(index: int) -> void:
	if world.request_online("dismiss",index):return
	if index>=0 and index<allies.size():allies.remove_at(index)
func set_destination(id: int) -> void:
	if world.request_online("destination",id):return
	destination=id
