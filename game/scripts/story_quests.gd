extends RefCounted
## Original goals/text/flags, with rebuilt offline glue for removed scripts.
var owner_ref: WeakRef
var world:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var data: Dictionary={}
var flags: int=0
var last_reply: String=""

func setup(owner_world,source: Variant) -> void:
	owner_ref=weakref(owner_world)
	data=source if source is Dictionary else {}
	reset()

func reset() -> void:flags=0;last_reply=""
func has(bit: int) -> bool:return (flags&bit)!=0
func minimum_level() -> int:return int(data.get("requirements",{}).get("minimum_level",50))

func update() -> void:
	if world!=null and not data.is_empty() and world.level>=minimum_level() and not has(1):
		flags|=1;world.message="Story quest available: Fight Aguilas' Spy. Open JOURNEY → STORY."

func active() -> bool:return has(1)
func complete() -> bool:return has(64)
func film() -> bool:return int(world.inventory.get("5:1",0))>0

func text(id: int) -> String:return str(data.get("messages",{}).get(str(id),""))
func words(ids: Array) -> String:
	var result: PackedStringArray=[]
	for id in ids:result.append(text(int(id)))
	return "\n\n".join(result)

func title() -> String:
	if not active():return "Story unlocks at level %d" % minimum_level()
	if complete():return "Recovered chapter complete"
	if has(32):return "Report to Kasham"
	if has(16):return "Defeat Esper"
	if has(8):return text(234)
	if has(4):return "Find the Geographer"
	if has(2) and film():return text(232)
	return text(230)

func objective() -> String:
	if not active():return "Reach level %d to begin the recovered Spy story." % minimum_level()
	if complete():return "The recovered first chapter is complete. Your honor cap is ±400. Later chapters are not playable yet."
	if has(32):return "Return to Kasham's House and report Esper's defeat."
	if has(16):return "Find and defeat the quest Esper in Sahara Dungeon 1, then return to Kasham."
	if has(8):return text(235)
	if has(4):return text(233)+"\nThe quest Geographer is in Street 3."
	if has(2) and film():return "Bring the Microfilm to the Archeologist in Downtown 2."
	return text(231)

func destinations() -> Array:
	if not active():return []
	var result: Array=[74]
	if has(2):result.append(37)
	if has(4):result.append(29)
	if has(8):result.append(75)
	if has(16):result.append(72)
	if has(64):result.append(36)
	return result

func next_destination() -> int:
	if not active() or complete():return -1
	if has(32) or has(8) and not has(16):return 75
	if has(16):return 72
	if has(4):return 29
	if has(2) and film():return 37
	return 74

func role(npc: Dictionary) -> String:
	for source in data.get("npcs",[]):
		if int(source["map_id"])==int(npc.get("map_id",-1)) and int(source["event_id"])==int(npc.get("event_id",-2)) and source["name"]==npc.get("name",""):return str(source["story_role"])
	return ""

func can_talk(npc: Dictionary) -> bool:
	if role(npc).is_empty() or int(npc.get("map_id",-1))!=world.map_id:return false
	for source in data.get("npcs",[]):
		if source["name"]==npc.get("name","") and int(source["map_id"])==world.map_id and int(source["event_id"])==int(npc.get("event_id",-1)):
			return world.npc_position(source).distance_to(world.player)<8
	return false

func action(npc: Dictionary) -> String:
	if not active():return ""
	match role(npc):
		"archeologist":return "QUIZ" if has(2) and not has(4) and film() else ""
		"geographer":return "MAKE THE MAP" if has(4) and not has(8) else ""
		"kasham":
			if has(8) and not has(16):return "ACCEPT ESPER MISSION"
			if has(32) and not has(64):return "REPORT ESPER'S DEFEAT"
	return ""

func greeting(npc: Dictionary) -> String:
	if not active():return "Come back at level %d to help us oppose Aguilas." % minimum_level()
	match role(npc):
		"archeologist":
			if action(npc)=="QUIZ":return words([189,190,191])
			if has(4):return words([200,201,202])
			return "Bring the Spy's Microfilm and I can help decode it.\n\n"+objective()
		"geographer":return words([203,204]) if action(npc)!="" else objective()
		"kasham":
			if has(32) and not complete():return words([215,216])
			if has(8) and not has(16):return words([210,211,212,213,214])
			return objective()
	return objective()

func finish(npc: Dictionary,choice: int=-1,path: String="user://progress.json") -> bool:
	if not can_talk(npc):world.message="Move closer to this person.";return false
	var verb: String=action(npc)
	if verb.is_empty():return false
	var old_flags: int=flags;var old_items: Dictionary=world.inventory.duplicate(true);var old_honor: int=world.honor
	var old_progress: Dictionary=progress_checkpoint();var earned: int=0
	if verb=="QUIZ":
		if choice<0 or choice>3:return false
		world.inventory["5:1"]=int(world.inventory.get("5:1",0))-1
		if choice==0:flags|=4;last_reply=words([197,198,199,200,201,202])
		else:last_reply=text(196)+"\n\nRecover another Microfilm from the Spy's house."
	elif verb=="MAKE THE MAP":
		flags|=8;increase_abs_honor(30);last_reply=words([205,206,207,208,209])+"\n\nHonor cap raised to ±300."
		earned=world.award_experience(world.rules.experience[200]/50)
	elif verb=="ACCEPT ESPER MISSION":
		flags|=16;last_reply=words([212,213,214])+"\n\nYour destination is Sahara Dungeon 1."
	elif verb=="REPORT ESPER'S DEFEAT":
		flags|=64;increase_abs_honor(50);world.inventory["5:102"]=int(world.inventory.get("5:102",0))+1
		last_reply=words([215,216,217,218,219])+"\n\nHonor cap raised to ±400. Received Sahara1 Map."
		earned=world.award_experience(world.rules.experience[300]/50)
	if world.save_game(path)!=OK:
		flags=old_flags;world.inventory=old_items;world.honor=old_honor;restore_progress(old_progress);world.message="Could not save quest progress. Your items were kept.";return false
	if earned>0:last_reply+="\n\n+%d XP" % earned
	world.message=title();return true

func increase_abs_honor(amount: int) -> void:
	if world.honor==0 or absi(world.honor)>=world.honor_cap():return
	world.honor=signi(world.honor)*mini(world.honor_cap(),absi(world.honor)+amount)

func on_defeat(id: int) -> void:
	update()
	if not active():return
	if world.map_id==74 and id==90 and not has(4) and not film():
		var before: int=flags;flags|=2;world.inventory["5:1"]=1
		var checkpoint: Dictionary=progress_checkpoint()
		if (before&2)==0:world.award_experience(world.rules.experience[100]/50)
		if world.save_game()!=OK:flags=before;world.inventory["5:1"]=0;restore_progress(checkpoint);world.message="Could not save the Microfilm. Return to retry the Spy encounter.";return
		world.message="Microfilm recovered · Honor cap ±200. Visit the Archeologist in Downtown 2."
	elif world.map_id==72 and id==92 and has(16) and not has(32):
		flags|=32
		if world.save_game()!=OK:flags&=~32;world.message="Could not save the victory. Return to retry the Esper encounter.";return
		world.message="Esper defeated. Return to Kasham's House."

func progress_checkpoint() -> Dictionary:
	return {"level":world.level,"xp":world.xp,"bonus_points":world.bonus_points,"hp":world.hp,"mana":world.mana}

func restore_progress(checkpoint: Dictionary) -> void:
	for key in checkpoint:world.set(key,checkpoint[key])

func prepare_travel(id: int) -> void:
	# The original scripts that reset these encounter rooms are Removed.
	# Reset a spent required encounter on re-entry so failed/lost-film attempts
	# cannot strand a save behind the source's two-billion-second respawn timer.
	var required: int=90 if id==74 and active() and not has(4) and not film() else 92 if id==72 and has(16) and not has(32) else -1
	if required<0:return
	var state: Dictionary=world.map_states.get(str(id),{})
	var found: bool=false
	for enemy in state.get("enemies",[]):
		if int(enemy.get("monster_id",-1))==required:
			found=true
			if not bool(enemy.get("alive",true)):world.map_states.erase(str(id));return
	if not found and not state.is_empty():world.map_states.erase(str(id))

func prioritize(candidates: Array) -> void:
	if world==null:return
	var target: int=92 if world.map_id==72 and has(16) and not has(32) else 90 if world.map_id==74 and active() and not has(4) else -1
	if target<0:return
	for source in candidates:
		if int(source.get("monster_id",-1))==target:candidates.erase(source);candidates.push_front(source);return

func encounter_hp(id: int) -> int:
	# Constitution is used as the offline encounter HP, not a claimed original
	# monster HP formula. Ordinary creatures keep the existing combat model.
	if world==null:return 36
	if (world.map_id==74 and id==90) or (world.map_id==72 and id==92):return maxi(36,int(world.monster_metadata.get(id,{}).get("constitution",36)))
	return 36

func target_name(id: int) -> String:
	if world.map_id==74 and id==90 and active() and not has(4):return "SPY · QUEST"
	if world.map_id==72 and id==92 and has(16) and not has(32):return "ESPER · QUEST"
	return ""

func serialize() -> Dictionary:return {"schema_version":1,"flags":flags}
func restore(saved: Variant) -> void:
	reset()
	if saved is Dictionary and world.valid_number(saved.get("flags",0)):
		var value: int=int(saved.get("flags",0))
		if value>=0 and value<=127:
			flags=value
			for pair in [[2,1],[4,2],[8,4],[16,8],[32,16],[64,32]]:
				if has(pair[0]) and not has(pair[1]):flags=0;break
	update()
