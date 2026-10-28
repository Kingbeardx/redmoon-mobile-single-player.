extends RefCounted
## Original IDs/ranges/intervals; damage and status safety limits are offline rules.
var owner_ref: WeakRef
var world:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var catalog: Dictionary={}

func engagement_distance(id: int) -> float:
	if world==null:return 1.35
	var info: Dictionary=world.monster_metadata.get(id,{})
	if world.complete_combat and int(info.get("attack_range_1",1))>1:return clampf(float(info["attack_range_1"]),1.35,10)
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
		if row["mode"] not in ["heal","linked_heal","linked_cleanse","summon","stealth","blessing"] and (pos.distance_to(world.player)>maxf(1,float(row["range"])) or not world.clear_sight(pos,world.player)):continue
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
	if mode in ["steal","stealth","nightmare","hold_summon","summon","linked_heal","linked_cleanse","disarm_drop","monster_curse","blessing"]:return reconstructed(enemy,row)
	if mode=="heal":
		if float(enemy.get("curse_time",0))>0:return false
		var maximum: int=int(enemy.get("max_hp",36));var healing: int=maxi(1,maximum*int(row["multiplier"])/100)
		enemy["hp"]=mini(maximum,int(enemy["hp"])+healing)
	else:
		var pos:=Vector2(float(enemy["x"]),float(enemy["y"]))
		if pos.distance_to(world.player)>maxf(1,float(row["range"])) or not world.clear_sight(pos,world.player):return false
		if mode in ["damage","physical_damage"]:
			var base: int=world.combat.monster_damage(world,enemy,mode=="damage") if world.complete_combat else 4
			var damage: int=maxi(1,int(ceil(base*float(row["multiplier"])/100.0)))
			if mode!="physical_damage" or float(enemy.get("blind_time",0))<=0:world.receive_damage(damage,enemy,mode=="damage")
		else:
			var source: Dictionary=world.monster_metadata.get(int(enemy.get("monster_id",0)),{})
			var duration: float=maxf(1,int(row["duration_base"])+int(source.get("spirit",0))/20)
			if mode=="poison":duration=maxf(1,int(source.get("spirit",0))/30)
			world.skills.apply_ailment(mode,duration)
		world.skills.effects.append({"skill_id":id,"start_x":pos.x,"start_y":pos.y,"facing":world.facing_for(pos.direction_to(world.player)),"x":world.player.x,"y":world.player.y,"mode":"hostile","remaining":.65,"label":"ENEMY SKILL"})
	return true

func reconstructed(enemy: Dictionary,row: Dictionary) -> bool:
	var mode: String=row["mode"];var origin:=Vector2(enemy["x"],enemy["y"])
	if mode not in ["stealth","summon","linked_heal","linked_cleanse","blessing"] and (origin.distance_to(world.player)>maxf(1,float(row["range"])) or not world.clear_sight(origin,world.player)):return false
	match mode:
		"stealth":
			if float(enemy.get("stealth_time",0))>0:return false
			enemy["stealth_time"]=5.0
		"nightmare":
			world.skills.buffs.clear();world.receive_damage(maxi(1,world.max_hp()/10),enemy,true);world.skills.apply_ailment("sleep",3)
		"monster_curse":
			world.skills.apply_ailment("slow",6);world.skills.buffs.clear();world.receive_damage(4,enemy,true)
		"steal","disarm_drop":
			var key: String=""
			for candidate in world.inventory:
				if candidate.get_slice(":",0) in ["1","2","3","4"] and int(world.inventory[candidate])>0 and not world.equipment.values().has(candidate):key=candidate;break
			if key.is_empty():return false
			world.inventory[key]=int(world.inventory[key])-1
			if mode=="steal":
				var stolen: Dictionary=enemy.get("stolen",{});stolen[key]=int(stolen.get(key,0))+1;enemy["stolen"]=stolen;world.message="A creature stole "+world.item_name(key)+". Defeat it to recover your item."
			else:
				var point: Vector2=world.find_start([int(world.player.x)+2,int(world.player.y)])
				world.drop_loot(key,point);world.message="An item was knocked to the ground."
		"linked_cleanse":
			var cleaned: bool=false
			for ally in world.enemies:
				if not bool(ally.get("alive",false)) or origin.distance_to(Vector2(ally["x"],ally["y"]))>maxf(1,float(row["range"])):continue
				for key in ["root_time","weaken_time","slow_time","stun_time","sleep_time","freeze_time","blind_time","expose_time","confuse_time","curse_time","voodoo_time"]:
					if float(ally.get(key,0))>0:cleaned=true;ally.erase(key)
			if not cleaned:return false
		"linked_heal":
			if int(enemy.get("healing_count",0))>=3:return false
			var targets: Array=[]
			for ally in world.enemies:
				if bool(ally.get("alive",false)) and origin.distance_to(Vector2(ally["x"],ally["y"]))<=maxf(1,float(row["range"])) and float(ally.get("curse_time",0))<=0 and int(ally["hp"])<int(ally.get("max_hp",36)):targets.append(ally)
			if targets.is_empty():return false
			targets.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a["hp"])/maxi(1,int(a.get("max_hp",36)))<float(b["hp"])/maxi(1,int(b.get("max_hp",36))))
			var target: Dictionary=targets[0];target["hp"]=mini(int(target.get("max_hp",36)),int(target["hp"])+maxi(1,int(target.get("max_hp",36))/4));enemy["healing_count"]=int(enemy.get("healing_count",0))+1;world.skills.clear_enemy_status(target)
		"hold_summon","summon":
			for old in world.enemies.duplicate():
				if bool(old.get("summoned",false)) and not bool(old.get("alive",false)):world.enemies.erase(old)
			if int(enemy.get("summon_count",0))>=3 or world.enemies.size()>=world.MAX_ENEMIES+6:return false
			var id: int=52 if mode=="hold_summon" else 55
			if not world.monster_metadata.has(id):return false
			var point: Vector2=world.find_start([int(origin.x)+1,int(origin.y)])
			var health: int=maxi(100,world.basic_attack_power()*5) if enemy.has("campaign_id") else world.story.encounter_hp(id)
			var minion: Dictionary={"monster_id":id,"hp":health,"max_hp":health,"x":point.x,"y":point.y,"alive":true,"cooldown":1.4,"respawn_seconds":60,"summoned":true}
			if enemy.has("campaign_id"):minion["scaled_encounter"]=int(enemy["campaign_id"])
			world.enemies.append(minion)
			enemy["summon_count"]=int(enemy.get("summon_count",0))+1
			if mode=="hold_summon":world.skills.apply_ailment("root",3)
		"blessing":
			for ally in world.enemies:
				if bool(ally.get("alive",false)) and origin.distance_to(Vector2(ally["x"],ally["y"]))<=maxf(1,float(row["range"])):ally["monster_buff_time"]=10.0
	world.skills.effects.append({"skill_id":int(row["id"]),"x":origin.x,"y":origin.y,"mode":"hostile","remaining":.65,"label":mode.to_upper().replace("_"," ")})
	return true
