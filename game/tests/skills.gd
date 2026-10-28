extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func reset(w,hero: int=1) -> void:
	w.character_id=hero;w.level=1;w.honor=0;w.stats={"strength":90,"spirit":90,"dexterity":90,"power":90};w.hp=w.max_hp();w.mana=w.max_mana();w.skills.reset();w.attack_cooldown=0;w.equipment={}
	w.enemies=[{"monster_id":5,"x":w.player.x,"y":w.player.y,"hp":10000,"alive":true,"cooldown":100.0,"respawn_seconds":10}]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var w=load("res://scripts/world.gd").new();check(w.initialize(),"real content loads")
	reset(w)
	check(w.skills.catalog.size()==114,"all 114 original player skills loaded")
	w.skills.ensure_slots();check(w.skills.slots==[11,-1,101],"Azlar starts with Psychic Shock and training alternative")
	check(w.skills.cast(11) and w.mana==97 and w.enemies[0]["hp"]==9982,"Psychic Shock uses original 7% maximum mana and 150% multiplier")
	var mana: int=w.mana;check(not w.skills.cast(11) and w.mana==mana,"repeated input cannot bypass recovery")
	reset(w);w.enemies=[];check(not w.skills.cast(11) and w.mana==104,"no target does not consume mana or start recovery")
	check(not w.skills.cast(-1) and w.mana==104,"training fallback also refunds failed target cast")
	reset(w);w.mana=0;check(not w.skills.cast(11) and w.enemies[0]["hp"]==10000,"insufficient mana cannot damage enemy")
	reset(w);check(not w.skills.cast(3) and w.mana==104,"foreign character skill denied without payment")
	reset(w,0);check(not w.skills.cast(3),"Soul Sphere locked until original level 50")
	w.level=50;check(w.skills.requirement(3)=="Ready","level unlock automatic without invented skill points")
	w.level=500;check(w.skills.requirement(10).begins_with("Requires honor"),"positive honor branch locked at neutral honor")
	w.honor=450;check(w.skills.requirement(10)=="Ready","positive honor threshold allows good branch")
	check(w.skills.requirement(8).begins_with("Requires honor"),"opposite honor branch blocked")
	w.honor=-250;check(w.skills.requirement(8)=="Ready","negative honor threshold allows evil branch")
	check(not w.skills.cast(6),"pending gate is not a fake damage skill")
	reset(w,0);w.hp=60;check(w.skills.cast(1) and w.hp==104 and w.mana==82,"Cure converts 22 MP to 44 HP")
	reset(w,0);check(not w.skills.cast(1) and w.mana==104,"full health cure consumes no mana")
	reset(w);w.level=50;w.enemies.append({"monster_id":5,"x":w.player.x,"y":w.player.y,"hp":10000,"alive":true})
	check(w.skills.cast(12) and w.enemies.all(func(e:Dictionary)->bool:return e["hp"]<10000),"Ice Rain damages all in-range targets")
	reset(w);w.level=100;check(w.skills.cast(13),"Absolute Defense casts")
	var hp: int=w.hp;mana=w.mana;w.receive_damage(10);check(w.hp==hp and w.mana==mana-10,"Absolute Defense absorbs incoming damage using mana")
	w.mana=3;w.receive_damage(10);check(w.mana==0 and w.hp==hp-7,"exhausted mana shield spills remaining damage to HP")
	reset(w,4);check(w.skills.cast(41),"Jarexx Will Power available at level one")
	check(w.skills.factor("attack_up")==1.2,"Will Power applies original 120% modifier")
	w.skills.tick(35);check(w.skills.active("attack_up").is_empty(),"timed buff expires")
	reset(w,3);check(w.skills.cast(31),"Destino Disguise available at level one")
	check(not w.skills.active("disguise").is_empty(),"Disguise persists as active buff")
	w.attack_cooldown=0;w.attack();check(w.skills.active("disguise").is_empty(),"attacking breaks disguise")
	reset(w,5);check(not w.skills.cast(51),"Sharpshoot requires compatible firearm")
	w.equipment={"weapon":"1:52"};check(w.skills.cast(51),"Sharpshoot works after equipping gun")
	reset(w,6);w.level=100;check(w.skills.cast(63) and w.enemies[0]["root_time"]>0,"Kitara Fetters applies root")
	reset(w,8);w.level=100;check(w.skills.cast(83) and w.enemies[0]["stun_time"]>0,"Lavita Hold stuns target")
	reset(w,8);check(w.skills.cast(81) and w.enemies[0]["weaken_time"]>0,"Lavita Enticement weakens target defenses")
	reset(w,7);w.level=50;check(w.skills.cast(72) and w.skills.factor("haste")==2,"Lunarena Hasten applies original 200% movement modifier")
	reset(w);w.skills.ensure_slots();check(w.skills.assign(2,11) and w.skills.slots[0]==0 and w.skills.slots[2]==11,"assign moves skill without duplicate slots")
	check(not w.skills.assign(0,12),"locked skill cannot be assigned")
	check(not w.skills.assign(9,11),"invalid slot rejected")
	w.skills.cast(11);var path: String="user://skill-test.json";w.save_game(path)
	var restored=load("res://scripts/world.gd").new();restored.initialize();check(restored.load_game(path) and restored.skills.slots==w.skills.slots,"hotbar survives save and reload")
	check(restored.skills.cooldowns.has(11),"reload retains skill cooldown")
	reset(w,4);w.honor=-50;w.skills.cast(41);w.save_game(path);restored.load_game(path)
	check(restored.honor==-50 and not restored.skills.active("attack_up").is_empty(),"honor and timed buff survive reload")
	var record: Dictionary=w.read_json(path);record["skills"]["saved_at"]=Time.get_unix_time_from_system()-100
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(record));f.close();restored.load_game(path)
	check(restored.skills.buffs.is_empty(),"elapsed real time expires saved buffs")
	restored.skills.restore({"slots":[{},11,INF],"saved_at":[],"buffs":{"11":{"remaining":100}},"cooldowns":{"11":"bad"}})
	check(restored.skills.buffs.is_empty() and restored.skills.cooldowns.is_empty(),"malformed optional skill state cannot install effects or timers")
	# Every admitted skill must execute with its actual class/level/equipment.
	var count: int=0
	for row in w.skills.catalog.values():
		if row["mode"]=="pending":continue
		reset(w,int(row["hero"]));w.level=1000;w.honor=int(row["honor"]);w.stats["spirit"]=15000;w.mana=w.max_mana();w.hp=1
		var weapons: Dictionary={"sword":"1:1","spear":"1:83","bow":"1:33","gun":"1:52","firearm":"1:52"}
		if row["mode"]=="warp":
			check(w.skills.cast(int(row["id"]),w.player+Vector2(.2,0)),"supported original warp executes");count+=1;continue
		if row["mode"]=="danger_attack":w.danger=w.max_danger()
		if row["mode"]=="cleanse":w.skills.ailments={"root":3.0}
		if row["weapon"]!="":w.equipment={"weapon":weapons[row["weapon"]]}
		check(w.skills.cast(int(row["id"])),"supported original skill executes: "+row["name"]);count+=1
	check(count==108,"all 108 admitted skills exercised")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute(path+suffix)
	print("SKILLS: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
