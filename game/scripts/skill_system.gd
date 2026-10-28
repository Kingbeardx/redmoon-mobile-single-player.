extends RefCounted
## Original requirements and names; supported effects run in the offline model.
var owner_ref: WeakRef
var world:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var catalog: Dictionary={}
var slots: Array=[]
var cooldowns: Dictionary={}
var buffs: Dictionary={}
var effects: Array=[]
var ailments: Dictionary={}
var control_grace: float=0
var poison_elapsed: float=0
const CONTROL_TYPES=["root","freeze","sleep"]
const BUFF_MODES=["disguise","attack_up","haste","mana_shield","barrier","reload","range_up","fear_aura","status_guard","purify_guard","decoy","taunt","hide","attack_speed","psychic_reflect","berserker","nimble","zephyrus","evasion","snipe","scatter","chain","starlight","holy_shield","damned_armor","purity","telekinesis"]
const RECOVERY: float=.8 # Offline input pacing, not an original server delay.

func setup(owner_world,data: Variant) -> void:
	owner_ref=weakref(owner_world)
	if data is Dictionary:
		for row in data.get("skills",[]):catalog[int(row["id"])]=row
	reset()

func reset() -> void:
	slots=[];cooldowns.clear();buffs.clear();effects.clear();ailments.clear();control_grace=0
	poison_elapsed=0

func for_hero(hero: int=-1) -> Array:
	var rows: Array=[]
	for row in catalog.values():
		if int(row["hero"])==(world.character_id if hero<0 else hero):rows.append(row)
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if int(a["kind"])!=int(b["kind"]):return int(a["kind"])<int(b["kind"])
		if int(a["level"])!=int(b["level"]):return int(a["level"])<int(b["level"])
		return int(a["id"])<int(b["id"]))
	return rows

func ensure_slots() -> void:
	if slots.size()==3:return
	var starter: int=0
	for row in for_hero():
		if int(row["kind"])==0 and int(row["level"])==1 and row["mode"]!="pending":starter=int(row["id"]);break
	var special: int=0
	for row in for_hero():
		if int(row["kind"])==1:special=int(row["id"]);break
	slots=[starter,-1,special]

func entry(id: int) -> Dictionary:
	if id==-1:return {"id":-1,"name":"Training Strike","description":"Offline training attack. This is not an original class skill.","mode":"training","level":1,"honor":0,"range":world.weapon_range(),"area":false,"kind":0,"mana_encoded":20,"weapon":""}
	return catalog.get(id,{})

func equipped_weapon() -> String:
	if world==null:return ""
	for key in world.equipment.values():
		if str(key).begins_with("1:"):
			# Original weapon families share stable eligibility masks, including
			# daggers/swords and grenades/launchers with no English family suffix.
			var mask: int=int(world.item_metadata.get(str(key),{}).get("characters",0))
			return {204:"sword",392:"bow",104:"gun",32:"firearm",16:"spear",320:"wand"}.get(mask,"")
	return ""

func requirement(id: int,include_runtime: bool=true) -> String:
	var row: Dictionary=entry(id)
	if row.is_empty():return "Empty slot"
	if id==-1:return "Ready"
	if int(row["hero"])!=world.character_id:return "Another character's skill"
	if world.level<int(row["level"]):return "Requires level %d" % int(row["level"])
	var honor: int=int(row["honor"])
	if honor>0 and world.honor<honor:return "Requires honor +%d" % honor
	if honor<0 and world.honor>honor:return "Requires honor %d" % honor
	if include_runtime and row["mode"]=="pending":return "Not reconstructed yet"
	var weapon: String=str(row["weapon"])
	if not weapon.is_empty():
		var actual: String=equipped_weapon()
		if actual!=weapon and not (weapon=="firearm" and actual in ["gun","firearm"]):return "Equip a %s first" % weapon
	return "Ready"

func cost(id: int) -> int:
	var row: Dictionary=entry(id)
	if row.is_empty():return 0
	if row["mode"]=="hide" and not active("hide").is_empty():return 0
	# Cure / Heal convert one MP into two HP. Recover restores all missing HP.
	if id in [1,2]:return mini(world.mana,(world.max_hp()-world.hp)/2)
	var encoded: int=int(row["mana_encoded"])
	if encoded>=1000000000:
		var percent: int=encoded-1000000000
		return world.max_mana() if percent>=100 else world.max_mana()*percent/100
	return encoded

func has_resource(id: int) -> bool:
	if entry(id).get("mode","")=="danger_attack":return world.danger>=world.max_danger()
	return world.mana>=cost(id)

func assign(slot: int,id: int) -> bool:
	if slot<0 or slot>2 or (id!=0 and requirement(id)!="Ready"):return false
	ensure_slots()
	for i in range(3):
		if slots[i]==id and id!=0:slots[i]=0
	slots[slot]=id
	return true

func tick(delta: float) -> void:
	if world==null:return
	var seconds: float=maxf(0,delta)
	if ailments.has("poison"):
		poison_elapsed+=minf(seconds,float(ailments["poison"]))
		while poison_elapsed>=1:
			poison_elapsed-=1;world.receive_damage(maxi(1,2*(world.max_hp()/100)),{},false,true)
	else:poison_elapsed=0
	control_grace=maxf(0,control_grace-seconds)
	for name in ailments.keys():
		ailments[name]=maxf(0,float(ailments[name])-seconds)
		if ailments[name]<=0:
			ailments.erase(name)
			if name in CONTROL_TYPES:control_grace=2.0
	for id in cooldowns.keys():
		cooldowns[id]=maxf(0,float(cooldowns[id])-seconds)
		if cooldowns[id]<=0:cooldowns.erase(id)
	for id in buffs.keys():
		buffs[id]["remaining"]=maxf(0,float(buffs[id]["remaining"])-seconds)
		if buffs[id]["remaining"]<=0:buffs.erase(id)
	for e in effects:e["remaining"]-=seconds
	effects=effects.filter(func(e: Dictionary)->bool:return e["remaining"]>0)
	for enemy in world.enemies:
		for name in ["root_time","weaken_time","slow_time","stun_time","sleep_time","freeze_time","blind_time","expose_time","confuse_time","curse_time","voodoo_time"]:
			if enemy.has(name):enemy[name]=maxf(0,float(enemy[name])-seconds)

func active(mode: String) -> Dictionary:
	for buff in buffs.values():
		if buff["mode"]==mode:return buff
	return {}

func clear_enemy_status(enemy: Dictionary) -> void:
	for name in ["root","weaken","slow","stun","sleep","freeze","blind","expose","confuse","curse","voodoo"]:enemy.erase(name+"_time")

func factor(mode: String) -> float:
	var buff: Dictionary=active(mode)
	var value: float=maxf(.05,float(buff.get("multiplier",100))/100.0) if not buff.is_empty() else 1.0
	if mode=="attack_up" and not active("starlight").is_empty():value=maxf(value,1.2)
	return value

func break_disguise() -> void:
	for id in buffs.keys():
		if buffs[id]["mode"]=="disguise":buffs.erase(id)

func basic_attack_delay() -> float:
	# Use the strongest rate rather than multiplying overlapping speed effects.
	var rate: float=maxf(1,factor("reload"))
	if not active("zephyrus").is_empty():rate=maxf(rate,1.2)
	for id in buffs:
		if buffs[id]["mode"]=="attack_speed":rate=maxf(rate,float(entry(int(id)).get("attack_speed",1)))
	return .45/clampf(rate,1,4)

func end_mode(mode: String) -> bool:
	var removed: bool=false
	for id in buffs.keys():
		if buffs[id]["mode"]==mode:buffs.erase(id);removed=true
	return removed

func cast_slot(slot: int) -> bool:
	ensure_slots()
	return cast(int(slots[slot])) if slot>=0 and slot<3 else false

func cast(id: int,destination: Vector2=Vector2(INF,INF)) -> bool:
	var reason: String=requirement(id)
	if reason!="Ready":world.message=reason;return false
	if world.hp<=0 or world.map_id<0:return false
	if float(cooldowns.get(id,0))>0 or world.attack_cooldown>0:world.message="Wait for the skill to recover.";return false
	if id==-1:
		if not can_act():world.message="You cannot act while frozen or asleep.";return false
		return world.cast_skill()
	var row: Dictionary=entry(id);var mode: String=str(row["mode"]);var used: int=cost(id)
	if mode=="warp":
		if not destination.is_finite():world.message="Choose a visible open tile for Warp.";return false
		if not can_move() or destination.distance_to(world.player)>10 or not world.can_stand(destination) or not world.clear_sight(world.player,destination) or destination.distance_to(world.player)<.1:world.message="Warp needs a nearby visible open tile and freedom to move.";return false
	if mode=="rush" and not can_move():world.message="You cannot rush while held.";return false
	if mode=="zephyrus" and not active("zephyrus").is_empty():world.message="Zyphyrus is already active.";return false
	if mode=="danger_attack" and world.danger<world.max_danger():world.message="Danger Points fill when you take damage. A full meter is required.";return false
	if not can_act() and mode not in ["cleanse","purify_guard"]:world.message="You cannot act while frozen or asleep.";return false
	if mode=="hide" and not active("hide").is_empty():
		# Ending a defensive stance must never trap a player with no MP.
		end_mode("hide");world.attack_cooldown=.45;cooldowns[id]=RECOVERY;world.message="Hide ended.";return true
	if mode=="cleanse" and ailments.is_empty():world.message="You have no harmful effects to cleanse.";return false
	if mode=="decoy" and not active("decoy").is_empty():world.message="Scarecrow is still protecting you.";return false
	if world.mana<used:world.message="Not enough mana for "+row["name"]+".";return false
	var targets: Array=[]
	var offensive: bool=mode in ["damage","danger_attack","rush","voodoo","curse","energy_drain","vital_drain","expose","confuse","root","weaken","slow","sleep","freeze","blind","damage_blind","damage_freeze","leech"]
	var rush_end: Vector2=world.player
	if offensive:
		var limit: float=maxf(1,float(row["range"]))
		for enemy in world.enemies:
			if not bool(enemy.get("alive",false)):continue
			var pos:=Vector2(float(enemy["x"]),float(enemy["y"]))
			if world.player.distance_to(pos)<=limit and world.clear_sight(world.player,pos):targets.append(enemy)
		targets.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return world.player.distance_squared_to(Vector2(a["x"],a["y"]))<world.player.distance_squared_to(Vector2(b["x"],b["y"])))
		if targets.has(world.selected_enemy):targets.erase(world.selected_enemy);targets.push_front(world.selected_enemy)
		if targets.is_empty():world.message="No creature in range for "+row["name"]+".";return false
		if mode=="rush":
			var goal:=Vector2(targets[0]["x"],targets[0]["y"]);var direction: Vector2=world.player.direction_to(goal)
			rush_end=world.move_entity(world.player,direction*maxf(0,world.player.distance_to(goal)-.8))
			if rush_end.distance_to(goal)>1.6:world.message="The rush path is blocked.";return false
			targets=world.enemies.filter(func(e: Dictionary)->bool:
				var p:=Vector2(e["x"],e["y"])
				return bool(e.get("alive",false)) and Geometry2D.get_closest_point_to_segment(p,world.player,goal).distance_to(p)<1.2 and world.clear_sight(world.player,p))
		elif not bool(row["area"]):targets.resize(1)
	elif mode=="heal" and (world.hp>=world.max_hp() or used<=0):world.message="No wounds to heal.";return false
	elif mode=="restore" and world.hp>=world.max_hp() and world.mana>=world.max_mana():world.message="Your health and mana are already full.";return false
	var story_flags: int=world.story.flags
	world.mana-=used
	world.rest_elapsed=0
	if mode=="danger_attack":world.danger=0
	world.attack_cooldown=.45;world.attack_flash=.18;cooldowns[id]=RECOVERY
	if offensive:break_disguise()
	if offensive:
		world.facing=world.facing_for(world.player.direction_to(Vector2(targets[0]["x"],targets[0]["y"])));world.start_attack_animation(.45)
	var amount: int=0
	if mode in ["damage","danger_attack","rush","damage_blind","damage_freeze","leech","energy_drain","vital_drain"]:
		# Reuse the current offline combat base; full original attack pipeline is
		# not recovered. Apply the original skill's percentage and actual range.
		amount=maxi(1,int((12+world.weapon_bonus+(world.level-1)*2)*float(row["multiplier"])/100.0))
		if mode=="danger_attack":amount=maxi(1,world.rules.special_attack(world.level)*int(row["multiplier"])/100)
		elif not str(row["weapon"]).is_empty():amount=maxi(1,int(world.basic_attack_power()*float(row["multiplier"])/100.0*physical_factor()))
		amount=maxi(1,int(amount*factor("attack_up")))
		for enemy in targets:
			var before_hp: int=int(enemy["hp"])
			world.damage_enemy(enemy,amount)
			var actual_damage: int=before_hp-int(enemy["hp"])
			if mode in ["energy_drain","vital_drain"]:drain_energy(enemy,actual_damage,mode=="vital_drain")
			if mode=="leech":world.hp=mini(world.max_hp(),world.hp+actual_damage*int(row["leech_percent"])/100)
			if mode in ["damage_blind","damage_freeze"] and bool(enemy["alive"]):
				var ailment: String="blind_time" if mode=="damage_blind" else "freeze_time"
				enemy[ailment]=maxf(1,world.effective_stat("spirit")/20+int(row["duration_base"]))
			effects.append({"skill_id":id,"start_x":world.player.x,"start_y":world.player.y,"facing":world.facing_for(world.player.direction_to(Vector2(enemy["x"],enemy["y"]))),"x":enemy["x"],"y":enemy["y"],"mode":mode,"remaining":.65,"label":"−%d" % amount})
		if mode=="rush":world.player=rush_end
	elif mode=="warp":
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"buff","remaining":.65,"label":"WARP"});world.player=destination;break_disguise()
	elif mode=="restore":
		world.hp=world.max_hp();world.mana=world.max_mana()
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"heal","remaining":.65,"label":"RESTORED"})
	elif mode=="heal":
		amount=used*2 if id in [1,2] else world.max_hp()-world.hp
		world.hp=mini(world.max_hp(),world.hp+amount)
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"heal","remaining":.65,"label":"+%d" % amount})
	elif offensive:
		if mode=="voodoo":
			for creature in world.enemies:creature.erase("voodoo_time")
		var duration: float=maxf(1,world.effective_stat("spirit")/20+int(row["duration_base"]))
		for enemy in targets:
			enemy[mode+"_time"]=duration
			if int(row["effect"])==16:enemy["stun_time"]=duration
			effects.append({"skill_id":id,"start_x":world.player.x,"start_y":world.player.y,"facing":world.facing_for(world.player.direction_to(Vector2(enemy["x"],enemy["y"]))),"x":enemy["x"],"y":enemy["y"],"mode":mode,"remaining":.65,"label":row["name"]})
	elif mode=="cleanse":
		ailments.clear();control_grace=2.0
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"heal","remaining":.65,"label":"CLEANSED"})
	else:
		if mode in ["scatter","chain"]:end_mode("scatter");end_mode("chain")
		if mode=="purify_guard":ailments.clear();control_grace=2.0
		var duration: float=maxf(.2,(world.effective_stat("spirit")/int(row.get("duration_spirit_divisor",20))+int(row["duration_base"]))*float(row.get("duration_scale",1)))
		buffs[id]={"mode":mode,"remaining":duration,"multiplier":row.get("runtime_multiplier",row["multiplier"]),"name":row["name"]}
		if mode=="decoy":buffs[id]["charges"]=3
		if mode=="berserker":world.hp=mini(world.hp,world.max_hp());world.danger=mini(world.danger,world.max_danger())
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"buff","remaining":.65,"label":row["name"]})
	if mode=="telekinesis":world.collect_loot()
	world.message=str(row["name"])+(" · %d target(s)" % targets.size() if offensive else "")+" · %d MP" % used
	if mode=="danger_attack":if mode=="telekinesis":world.collect_loot()
	world.message=str(row["name"])+" · Danger Points consumed"
	if world.story.flags!=story_flags:world.message="Story updated · "+world.story.title()+" · Honor cap ±%d" % world.honor_cap()
	return true

func physical_factor() -> float:return 2.0 if not active("berserker").is_empty() else 1.0

func serialize() -> Dictionary:
	ensure_slots()
	return {"slots":slots,"cooldowns":cooldowns,"buffs":buffs,"ailments":ailments,"control_grace":control_grace,"poison_elapsed":poison_elapsed,"saved_at":Time.get_unix_time_from_system()}

func restore(saved: Dictionary) -> void:
	reset();ensure_slots()
	var ids: Variant=saved.get("slots",[])
	if ids is Array and ids.size()==3:
		for i in range(3):
			if not world.valid_number(ids[i]):continue
			var id: int=int(ids[i]);var row: Dictionary=entry(id)
			if id==0 or id==-1 or (not row.is_empty() and int(row.get("hero",-1))==world.character_id):slots[i]=id
	var timestamp: Variant=saved.get("saved_at",0)
	var away: float=maxf(0,Time.get_unix_time_from_system()-float(timestamp)) if world.valid_number(timestamp) else 3600
	var prior_grace: Variant=saved.get("control_grace",0)
	if world.valid_number(prior_grace):control_grace=clampf(float(prior_grace)-away,0,2)
	var prior_ailments: Variant=saved.get("ailments",{})
	if prior_ailments is Dictionary:
		for name in prior_ailments:
			if name not in ["root","freeze","sleep","blind","slow","poison"] or not world.valid_number(prior_ailments[name]):continue
			var remaining: float=clampf(float(prior_ailments[name])-away,0,3 if name in CONTROL_TYPES else 6)
			if remaining>0:ailments[name]=remaining
	var prior_poison: Variant=saved.get("poison_elapsed",0)
	if ailments.has("poison") and world.valid_number(prior_poison):
		poison_elapsed=clampf(float(prior_poison),0,0.999999)
	var timers: Variant=saved.get("cooldowns",{})
	if timers is Dictionary:
		for key in timers:
			if world.valid_number(timers[key]) and float(timers[key])>away:cooldowns[int(key)]=minf(RECOVERY,float(timers[key])-away)
	var prior: Variant=saved.get("buffs",{})
	if prior is Dictionary:
		for key in prior:
			var id: int=int(key);var row: Dictionary=entry(id);var old: Variant=prior[key]
			if row.is_empty() or int(row.get("hero",-1))!=world.character_id or not old is Dictionary:continue
			if row["mode"] not in BUFF_MODES:continue
			if not world.valid_number(old.get("remaining")):continue
			var remaining: float=minf(3600,float(old["remaining"])-away)
			if remaining>0:
				if row["mode"]=="decoy":
					var charges: Variant=old.get("charges",3)
					if not world.valid_number(charges) or int(charges)<1:continue
					buffs[id]={"mode":row["mode"],"remaining":remaining,"multiplier":row.get("runtime_multiplier",row["multiplier"]),"name":row["name"],"charges":clampi(int(charges),1,3)}
				else:buffs[id]={"mode":row["mode"],"remaining":remaining,"multiplier":row.get("runtime_multiplier",row["multiplier"]),"name":row["name"]}


func can_move() -> bool:
	for name in CONTROL_TYPES:
		if float(ailments.get(name,0))>0:return false
	return true

func can_act() -> bool:return not ailments.has("freeze") and not ailments.has("sleep")

func apply_ailment(name: String,duration: float) -> bool:
	if name not in ["root","freeze","sleep","blind","slow","poison"]:return false
	if name=="poison" and not ailments.has("poison"):poison_elapsed=0
	if not active("status_guard").is_empty() or not active("purify_guard").is_empty():return false
	if name in CONTROL_TYPES and control_grace>0:return false
	var remaining: float=clampf(duration,.2,3 if name in CONTROL_TYPES else 6)
	ailments[name]=maxf(remaining,float(ailments.get(name,0)))
	world.message="%s · %ds" % [name.to_upper(),int(ceil(remaining))]
	return true

func absorb_decoy() -> bool:
	for id in buffs:
		if buffs[id]["mode"]!="decoy":continue
		var charges: int=int(buffs[id].get("charges",3))-1
		if charges<=0:buffs.erase(id)
		else:buffs[id]["charges"]=charges
		world.message="Scarecrow blocked the attack · %d remaining" % charges
		return true
	return false

func drain_energy(enemy: Dictionary,damage: int,vital: bool) -> void:
	var info: Dictionary=world.monster_metadata.get(int(enemy.get("monster_id",0)),{})
	var spirit: int=maxi(0,int(info.get("spirit",0)))
	var maximum: int=50+(spirit/15)*(spirit/10)
	var current: int=clampi(int(enemy.get("mana",maximum)),0,maximum)
	var stamina: int=clampi(int(enemy.get("stamina",2000)),0,2000)
	var stolen_mp: int=mini(current,maxi(0,damage));var stolen_sp: int=mini(stamina,maxi(0,damage))
	enemy["mana"]=current-stolen_mp;enemy["stamina"]=stamina-stolen_sp
	world.mana=mini(world.max_mana(),world.mana+stolen_mp)
	world.stamina=mini(2000,world.stamina+stolen_sp)
	if vital:world.hp=mini(world.max_hp(),world.hp+maxi(0,damage))

func secondary_hits(primary: Dictionary,amount: int) -> void:
	var scatter: bool=not active("scatter").is_empty()
	if not scatter and active("chain").is_empty():return
	var anchor:=Vector2(primary["x"],primary["y"]);var visited: Array=[primary]
	var damage: int=amount/2 if scatter else amount
	for jump in range(3):
		var target: Dictionary={};var nearest: float=2.0 if scatter else 3.0
		for enemy in world.enemies:
			if visited.has(enemy) or not bool(enemy.get("alive",false)):continue
			var pos:=Vector2(enemy["x"],enemy["y"]);var distance: float=anchor.distance_to(pos)
			if distance<=nearest and world.clear_sight(anchor,pos):target=enemy;nearest=distance
		if target.is_empty():break
		if not scatter:damage=damage*3/4
		world.damage_enemy(target,maxi(1,damage));visited.append(target)
		effects.append({"x":target["x"],"y":target["y"],"mode":"damage","remaining":.65,"label":"−%d" % maxi(1,damage)})
		if not scatter:anchor=Vector2(target["x"],target["y"])
