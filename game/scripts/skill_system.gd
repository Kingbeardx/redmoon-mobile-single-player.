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
const CONTROL_TYPES=["root","freeze","sleep"]
const BUFF_MODES=["disguise","attack_up","haste","mana_shield","barrier","reload","range_up","fear_aura","status_guard","purify_guard","decoy","taunt"]
const RECOVERY: float=.8 # Offline input pacing, not an original server delay.

func setup(owner_world,data: Variant) -> void:
	owner_ref=weakref(owner_world)
	if data is Dictionary:
		for row in data.get("skills",[]):catalog[int(row["id"])]=row
	reset()

func reset() -> void:
	slots=[];cooldowns.clear();buffs.clear();effects.clear();ailments.clear();control_grace=0

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
	slots=[starter,-1,0]

func entry(id: int) -> Dictionary:
	if id==-1:return {"id":-1,"name":"Training Strike","description":"Offline training attack. This is not an original class skill.","mode":"training","level":1,"honor":0,"range":world.weapon_range(),"area":false,"kind":0,"mana_encoded":20,"weapon":""}
	return catalog.get(id,{})

func equipped_weapon() -> String:
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
	# Cure / Heal convert one MP into two HP. Recover restores all missing HP.
	if id in [1,2]:return mini(world.mana,(world.max_hp()-world.hp)/2)
	var encoded: int=int(row["mana_encoded"])
	if encoded>=1000000000:
		var percent: int=encoded-1000000000
		return world.max_mana() if percent>=100 else world.max_mana()*percent/100
	return encoded

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
		for name in ["root_time","weaken_time","slow_time","stun_time","sleep_time","freeze_time","blind_time"]:
			if enemy.has(name):enemy[name]=maxf(0,float(enemy[name])-seconds)

func active(mode: String) -> Dictionary:
	for buff in buffs.values():
		if buff["mode"]==mode:return buff
	return {}

func clear_enemy_status(enemy: Dictionary) -> void:
	for name in ["root","weaken","slow","stun","sleep","freeze","blind"]:enemy.erase(name+"_time")

func factor(mode: String) -> float:
	var buff: Dictionary=active(mode)
	return maxf(.05,float(buff.get("multiplier",100))/100.0) if not buff.is_empty() else 1.0

func break_disguise() -> void:
	for id in buffs.keys():
		if buffs[id]["mode"]=="disguise":buffs.erase(id)

func cast_slot(slot: int) -> bool:
	ensure_slots()
	return cast(int(slots[slot])) if slot>=0 and slot<3 else false

func cast(id: int) -> bool:
	var reason: String=requirement(id)
	if reason!="Ready":world.message=reason;return false
	if world.hp<=0 or world.map_id<0:return false
	if float(cooldowns.get(id,0))>0 or world.attack_cooldown>0:world.message="Wait for the skill to recover.";return false
	if id==-1:
		if not can_act():world.message="You cannot act while frozen or asleep.";return false
		return world.cast_skill()
	var row: Dictionary=entry(id);var mode: String=str(row["mode"]);var used: int=cost(id)
	if not can_act() and mode not in ["cleanse","purify_guard"]:world.message="You cannot act while frozen or asleep.";return false
	if mode=="cleanse" and ailments.is_empty():world.message="You have no harmful effects to cleanse.";return false
	if mode=="decoy" and not active("decoy").is_empty():world.message="Scarecrow is still protecting you.";return false
	if world.mana<used:world.message="Not enough mana for "+row["name"]+".";return false
	var targets: Array=[]
	var offensive: bool=mode in ["damage","root","weaken","slow","sleep","freeze","blind","damage_blind","damage_freeze","leech"]
	if offensive:
		var limit: float=maxf(1,float(row["range"]))
		for enemy in world.enemies:
			if not bool(enemy.get("alive",false)):continue
			var pos:=Vector2(float(enemy["x"]),float(enemy["y"]))
			if world.player.distance_to(pos)<=limit and world.clear_sight(world.player,pos):targets.append(enemy)
		targets.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return world.player.distance_squared_to(Vector2(a["x"],a["y"]))<world.player.distance_squared_to(Vector2(b["x"],b["y"])))
		if targets.is_empty():world.message="No creature in range for "+row["name"]+".";return false
		if not bool(row["area"]):targets.resize(1)
	elif mode=="heal" and (world.hp>=world.max_hp() or used<=0):world.message="No wounds to heal.";return false
	world.mana-=used
	world.attack_cooldown=.45;world.attack_flash=.18;cooldowns[id]=RECOVERY
	if offensive:break_disguise()
	var amount: int=0
	if mode in ["damage","damage_blind","damage_freeze","leech"]:
		# Reuse the current offline combat base; full original attack pipeline is
		# not recovered. Apply the original skill's percentage and actual range.
		amount=maxi(1,int((12+world.weapon_bonus+(world.level-1)*2)*float(row["multiplier"])/100.0))
		for enemy in targets:
			var before_hp: int=int(enemy["hp"])
			world.damage_enemy(enemy,amount)
			var actual_damage: int=before_hp-int(enemy["hp"])
			if mode=="leech":world.hp=mini(world.max_hp(),world.hp+actual_damage*int(row["leech_percent"])/100)
			if mode in ["damage_blind","damage_freeze"] and bool(enemy["alive"]):
				var ailment: String="blind_time" if mode=="damage_blind" else "freeze_time"
				enemy[ailment]=maxf(1,world.effective_stat("spirit")/20+int(row["duration_base"]))
			effects.append({"skill_id":id,"start_x":world.player.x,"start_y":world.player.y,"facing":world.facing_for(world.player.direction_to(Vector2(enemy["x"],enemy["y"]))),"x":enemy["x"],"y":enemy["y"],"mode":mode,"remaining":.65,"label":"−%d" % amount})
	elif mode=="heal":
		amount=used*2 if id in [1,2] else world.max_hp()-world.hp
		world.hp=mini(world.max_hp(),world.hp+amount)
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"heal","remaining":.65,"label":"+%d" % amount})
	elif offensive:
		var duration: float=maxf(1,world.effective_stat("spirit")/20+int(row["duration_base"]))
		for enemy in targets:
			enemy[mode+"_time"]=duration
			if int(row["effect"])==16:enemy["stun_time"]=duration
			effects.append({"skill_id":id,"start_x":world.player.x,"start_y":world.player.y,"facing":world.facing_for(world.player.direction_to(Vector2(enemy["x"],enemy["y"]))),"x":enemy["x"],"y":enemy["y"],"mode":mode,"remaining":.65,"label":row["name"]})
	elif mode=="cleanse":
		ailments.clear();control_grace=2.0
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"heal","remaining":.65,"label":"CLEANSED"})
	else:
		if mode=="purify_guard":ailments.clear();control_grace=2.0
		var duration: float=maxf(.2,(world.effective_stat("spirit")/int(row.get("duration_spirit_divisor",20))+int(row["duration_base"]))*float(row.get("duration_scale",1)))
		buffs[id]={"mode":mode,"remaining":duration,"multiplier":row["multiplier"],"name":row["name"]}
		if mode=="decoy":buffs[id]["charges"]=3
		effects.append({"x":world.player.x,"y":world.player.y,"mode":"buff","remaining":.65,"label":row["name"]})
	world.message=str(row["name"])+(" · %d target(s)" % targets.size() if offensive else "")+" · %d MP" % used
	return true

func serialize() -> Dictionary:
	ensure_slots()
	return {"slots":slots,"cooldowns":cooldowns,"buffs":buffs,"ailments":ailments,"control_grace":control_grace,"saved_at":Time.get_unix_time_from_system()}

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
			if name not in ["root","freeze","sleep","blind","slow"] or not world.valid_number(prior_ailments[name]):continue
			var remaining: float=clampf(float(prior_ailments[name])-away,0,3 if name in CONTROL_TYPES else 6)
			if remaining>0:ailments[name]=remaining
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
					buffs[id]={"mode":row["mode"],"remaining":remaining,"multiplier":row["multiplier"],"name":row["name"],"charges":clampi(int(charges),1,3)}
				else:buffs[id]={"mode":row["mode"],"remaining":remaining,"multiplier":row["multiplier"],"name":row["name"]}


func can_move() -> bool:
	for name in CONTROL_TYPES:
		if float(ailments.get(name,0))>0:return false
	return true

func can_act() -> bool:return not ailments.has("freeze") and not ailments.has("sleep")

func apply_ailment(name: String,duration: float) -> bool:
	if name not in ["root","freeze","sleep","blind","slow"]:return false
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
