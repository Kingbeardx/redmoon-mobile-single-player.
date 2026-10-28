extends RefCounted
## Original IDs/ranges/intervals; damage and status safety limits are offline rules.
var owner_ref: WeakRef
var world:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var catalog: Dictionary={}

func engagement_distance(id: int) -> float:
	if world==null:return 1.35
	var info: Dictionary=world.monster_metadata.get(id,{})
	for index in [1,2]:
		var row: Dictionary=catalog.get(int(info.get("skill_id_%d" % index,0)),{})
		if not row.is_empty() and row["mode"] not in ["pending","heal"] and int(row["range"])==1:return .85
	return 1.35

func setup(owner_world,data: Variant) -> void:
	owner_ref=weakref(owner_world);catalog.clear()
	if data is Dictionary:
		for row in data.get("monster_skills",[]):catalog[int(row["id"])]=row

func tick_enemy(enemy: Dictionary,delta: float) -> bool:
	if world==null or world.arrival_grace>0:return false
	var info: Dictionary=world.monster_metadata.get(int(enemy.get("monster_id",0)),{})
	var timers: Dictionary=enemy.get("skill_timers",{})
	enemy["cast_recovery"]=maxf(0,float(enemy.get("cast_recovery",0))-delta)
	for index in [1,2]:
		var id: int=int(info.get("skill_id_%d" % index,0));var interval: float=float(info.get("skill_interval_%d" % index,0))/1000.0
		if id<=0 or interval<=0 or not catalog.has(id):continue
		var key: String=str(index)
		timers[key]=maxf(0,float(timers.get(key,interval))-delta)
		if timers[key]>0 or float(enemy["cast_recovery"])>0:continue
		var row: Dictionary=catalog[id]
		if row["mode"]=="pending":continue
		var pos:=Vector2(float(enemy["x"]),float(enemy["y"]))
		if row["mode"]!="heal" and (pos.distance_to(world.player)>maxf(1,float(row["range"])) or not world.clear_sight(pos,world.player)):continue
		if row["mode"]=="heal" and int(enemy.get("hp",36))>=int(enemy.get("max_hp",36)):continue
		if not cast(enemy,id):continue
		timers[key]=maxf(1,interval);enemy["skill_timers"]=timers;enemy["cast_recovery"]=.8
		enemy["cooldown"]=maxf(.45,float(enemy.get("cooldown",0)))
		return true
	enemy["skill_timers"]=timers
	return false

func cast(enemy: Dictionary,id: int) -> bool:
	var row: Dictionary=catalog.get(id,{})
	if row.is_empty() or row["mode"]=="pending" or not bool(enemy.get("alive",false)):return false
	var mode: String=str(row["mode"])
	enemy["action_remaining"]=.55
	if mode=="heal":
		var maximum: int=int(enemy.get("max_hp",36));var healing: int=maxi(1,maximum*int(row["multiplier"])/100)
		enemy["hp"]=mini(maximum,int(enemy["hp"])+healing)
	else:
		var pos:=Vector2(float(enemy["x"]),float(enemy["y"]))
		if pos.distance_to(world.player)>maxf(1,float(row["range"])) or not world.clear_sight(pos,world.player):return false
		if mode in ["damage","physical_damage"]:
			var damage: int=maxi(1,int(ceil(4*float(row["multiplier"])/100.0)))
			if mode!="physical_damage" or float(enemy.get("blind_time",0))<=0:world.receive_damage(damage,enemy,mode=="damage")
		else:
			var source: Dictionary=world.monster_metadata.get(int(enemy.get("monster_id",0)),{})
			var duration: float=maxf(1,int(row["duration_base"])+int(source.get("spirit",0))/20)
			if mode=="poison":duration=maxf(1,int(source.get("spirit",0))/30)
			world.skills.apply_ailment(mode,duration)
		world.skills.effects.append({"skill_id":id,"start_x":pos.x,"start_y":pos.y,"facing":world.facing_for(pos.direction_to(world.player)),"x":world.player.x,"y":world.player.y,"mode":"hostile","remaining":.65,"label":"ENEMY SKILL"})
	return true
