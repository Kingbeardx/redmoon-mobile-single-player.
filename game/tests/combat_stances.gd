extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func prepare(w,id: int) -> void:
	var row: Dictionary=w.skills.entry(id)
	w.character_id=int(row["hero"]);w.level=int(row["level"]);w.honor=int(row["honor"]);w.stats["spirit"]=300;w.hp=w.max_hp();w.mana=w.max_mana();w.skills.reset();w.attack_cooldown=0;w.armor_bonus=0
	w.enemies=[{"monster_id":5,"hp":10000,"max_hp":10000,"alive":true,"x":w.player.x,"y":w.player.y,"cooldown":100.0}]
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize();w.enter_map(9)
	prepare(w,34);var mana: int=w.mana
	check(w.skills.cast(34) and w.mana==mana-w.max_mana()/10,"Hide pays original 10 percent maximum MP")
	check(is_equal_approx(float(w.skills.active("hide")["remaining"]),60),"Hide uses recovered Spirit/5 and 1000ms timer")
	var hp: int=w.hp;w.receive_damage(10,w.enemies[0]);check(w.hp==hp,"Hide avoids physical damage")
	w.monster_skills.cast(w.enemies[0],182);check(w.hp==hp,"Hide avoids physical monster skills")
	w.receive_damage(10,w.enemies[0],true);check(w.hp==hp-10,"Hide still takes psychic damage")
	w.attack_cooldown=0;w.skills.cooldowns.clear();w.mana=0
	check(w.skills.cast(34) and w.skills.active("hide").is_empty(),"Hide can be toggled off at zero MP")
	w.receive_damage(10,w.enemies[0]);check(w.hp==hp-20,"physical damage resumes after ending Hide")
	prepare(w,34);w.skills.cast(34);w.skills.tick(60.1);check(w.skills.active("hide").is_empty(),"Hide expires normally")
	prepare(w,34);w.skills.cast(34);w.attack_cooldown=0;check(w.attack() and not w.skills.active("hide").is_empty(),"Hide is a physical guard distinct from attack-breaking Disguise")
	for id in [48,312]:
		prepare(w,id);w.stats["spirit"]=15000;w.mana=w.max_mana();mana=w.mana
		check(w.skills.cast(id) and w.mana==mana-int(w.skills.entry(id)["mana_encoded"]),"attack speed pays original cost %d" % id)
		w.attack_cooldown=0;check(w.attack(),"basic attack works with speed stance %d" % id)
		check(is_equal_approx(w.attack_cooldown,.3 if id==48 else .225),"speed stance changes actual world attack delay %d" % id)
		check(w.skills.assign(2,id),"new stance can be bound to touch slot %d" % id)
		w.skills.tick(800);check(is_equal_approx(w.skills.basic_attack_delay(),.45),"expired stance restores normal attack rate %d" % id)
	prepare(w,48);w.skills.cast(48)
	w.skills.buffs[312]={"mode":"attack_speed","remaining":30,"multiplier":0,"name":"fixture"}
	w.skills.buffs[999]={"mode":"reload","remaining":30,"multiplier":150,"name":"fixture"}
	check(is_equal_approx(w.skills.basic_attack_delay(),.225),"overlapping speed effects use strongest rate instead of multiplication")
	prepare(w,65);mana=w.mana;check(w.skills.cast(65) and w.mana==mana-300,"Red Halo pays original MP cost")
	check(is_equal_approx(float(w.skills.active("psychic_reflect")["remaining"]),25),"Red Halo uses recovered duration")
	var target: Dictionary=w.enemies[0];hp=w.hp;w.receive_damage(10,target,true)
	check(w.hp==hp-10 and int(target["hp"])==9990,"Red Halo returns actual psychic HP damage without preventing original damage")
	w.receive_damage(10,target,false);check(int(target["hp"])==9990,"physical hits are not reflected")
	w.skills.buffs[13]={"mode":"mana_shield","remaining":30,"multiplier":75,"name":"fixture"};w.mana=20;hp=w.hp
	w.receive_damage(10,target,true);check(w.hp==hp and int(target["hp"])==9990,"fully absorbed damage does not create reflected damage")
	w.mana=3;w.receive_damage(10,target,true);check(w.hp==hp-7 and int(target["hp"])==9983,"only HP spill after mana shield is reflected")
	w.skills.buffs.erase(13);w.hp=2;w.receive_damage(10,target,true);check(w.hp==0 and int(target["hp"])==9981,"lethal reflection is capped to actual HP lost")
	w.receive_damage(10,target,true);check(int(target["hp"])==9981,"dead player cannot keep reflecting")
	prepare(w,65);w.skills.cast(65);target=w.enemies[0];hp=w.hp;w.receive_damage(10,{},true)
	check(w.hp==hp-10 and int(target["hp"])==10000,"environmental damage has no invented reflection target")
	target["hp"]=1;var kills: int=w.defeated;w.receive_damage(10,target,true)
	check(not target["alive"] and w.defeated==kills+1,"reflected kill follows ordinary defeat and reward path once")
	w.receive_damage(10,target,true);check(w.defeated==kills+1,"already dead attacker cannot award another reflected kill")
	for id in [34,48,312,65]:
		prepare(w,id);w.stats["spirit"]=15000;w.mana=w.max_mana();w.skills.cast(id)
		var path: String="user://stances.json";w.save_game(path)
		var copy=load("res://scripts/world.gd").new();copy.initialize();copy.load_game(path)
		check(not copy.skills.active(str(w.skills.entry(id)["mode"])).is_empty(),"stance survives save and reload %d" % id)
		for suffix in ["", ".bak"]:DirAccess.remove_absolute(path+suffix)
	print("COMBAT STANCES: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
