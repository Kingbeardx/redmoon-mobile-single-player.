extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func prepare(w,id: int) -> void:
	w.enter_map(9);w.width=30;w.height=30;w.walkable=[]
	for i in range(900):w.walkable.append(1)
	w.player=Vector2(10.5,10.5);w.enemies=[];w.skills.reset();w.attack_cooldown=0;w.arrival_grace=100
	var row: Dictionary=w.skills.entry(id)
	w.character_id=int(row["hero"]);w.level=1000;w.honor=int(row["honor"])
	w.stats={"strength":100,"spirit":15000,"dexterity":100,"power":300};w.hp=w.max_hp();w.mana=w.max_mana();w.danger=0;w.stamina=1000;w.armor_bonus=0;w.weapon_bonus=0
	w.equipment={"weapon":"1:1"} if row["weapon"]=="sword" else {"weapon":"1:52"} if row["weapon"] in ["gun","firearm"] else {}
func enemy(w,x: float=11,y: float=10.5) -> Dictionary:
	var e: Dictionary={"monster_id":5,"x":x,"y":y,"hp":100000,"max_hp":100000,"alive":true,"cooldown":100.0,"respawn_seconds":60};w.enemies.append(e);return e
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize()
	prepare(w,7);var e: Dictionary=enemy(w);check(w.skills.cast(7),"Voodoo links a target")
	w.receive_damage(20,e);check(e["hp"]==99980,"Voodoo mirrors actual HP damage")
	e["x"]=20;w.receive_damage(20,e);check(e["hp"]==99980,"Voodoo respects link distance")
	e["x"]=11;w.skills.tick(5000);w.receive_damage(20,e);check(e["hp"]==99980,"Voodoo expires")
	for id in [29,68]:
		prepare(w,id);e=enemy(w);e["hp"]=10;e["mana"]=7;e["stamina"]=5;w.hp=1
		var before: int=w.mana-w.skills.cost(id)
		check(w.skills.cast(id),"drain casts with original requirements %d" % id)
		check(e["mana"]==0 and e["stamina"]==0 and w.mana==before+7 and w.stamina==1005,"drain conserves finite creature energy %d" % id)
		check(w.hp==(11 if id==68 else 1),"only Drain restores actual lost creature HP")
		var mp: int=w.mana;w.skills.drain_energy(e,1000,false);check(w.mana==mp,"depleted creature cannot mint MP")
	prepare(w,7);var mp: int=w.mana;check(not w.skills.cast(7) and w.mana==mp,"failed link spends no MP")
	prepare(w,305);e=enemy(w);check(w.skills.cast(305),"Soul Crush applies a curse")
	e["hp"]=5;check(not w.monster_skills.cast(e,183) and e["hp"]==5,"curse blocks monster healing")
	w.skills.tick(5000);check(w.monster_skills.cast(e,183) and e["hp"]>5,"healing resumes after curse expires")
	prepare(w,314);e=enemy(w);w.skills.cast(314);var hp: int=w.hp;w.receive_damage(120,e);check(w.hp==hp-100,"Holy Shield uses 120 protection multiplier")
	prepare(w,315);e=enemy(w);w.skills.cast(315);hp=w.hp;w.receive_damage(20,e);check(w.hp==hp-20 and e["hp"]==99990,"Damned Armor reflects half actual HP damage")
	w.hp=3;w.receive_damage(20,e);check(e["hp"]==99989,"reflection cannot use overkill damage")
	prepare(w,315);e=enemy(w);w.skills.cast(315);w.receive_damage(20,e,false,true);check(e["hp"]==100000,"poison does not trigger armor reflection")
	prepare(w,304);e=enemy(w);w.skills.cast(304);hp=w.hp;w.receive_damage(100,e);check(w.hp==hp-80 and w.skills.factor("attack_up")==1.2,"Starlight provides offline self support")
	prepare(w,361);e=enemy(w);w.skills.cast(361);w.receive_damage(70,e);check(w.danger==100,"Purity accelerates DP gain")
	prepare(w,38);w.skills.cast(38);seed(16);hp=w.hp
	for i in range(100):w.receive_damage(1)
	check(w.hp<hp and w.hp>hp-100,"Evasion can avoid physical hits without invulnerability")
	hp=w.hp;w.receive_damage(10,{},true);check(w.hp==hp-10,"Evasion cannot avoid psychic damage")
	prepare(w,56);e=enemy(w,18);check(not w.attack(),"ordinary gun cannot reach distant opponent")
	w.attack_cooldown=0;check(w.skills.cast(56),"Snipe casts")
	w.attack_cooldown=0;check(w.attack() and e["hp"]<100000,"Snipe extends actual gun attacks")
	w.skills.tick(5000);check(w.weapon_range()<10,"Snipe range expires")
	for id in [58,59]:
		prepare(w,id);e=enemy(w);var second: Dictionary=enemy(w,12);var third: Dictionary=enemy(w,13)
		check(w.skills.cast(id),"multi-target buff casts %d" % id);w.attack_cooldown=0;w.selected_enemy=e
		check(w.attack() and second["hp"]<100000 and third["hp"]<100000,"ordinary attack triggers secondary targets %d" % id)
		check(e["hp"]<second["hp"],"secondary attacks are weaker than direct hit")
	prepare(w,58);w.skills.cast(58);w.attack_cooldown=0;w.honor=int(w.skills.entry(59)["honor"]);w.skills.cast(59)
	check(w.skills.active("scatter").is_empty() and not w.skills.active("chain").is_empty(),"scatter and chain do not stack")
	prepare(w,29);e=enemy(w);e["mana"]=0;e["stamina"]=0;e["curse_time"]=5;w.remember_map();var state: Dictionary=w.map_states[str(w.map_id)].duplicate(true);w.enemies=[];w.restore_map_state(state)
	check(w.enemies[0].get("mana",-1)==0 and w.enemies[0].get("stamina",-1)==0,"map reload preserves depleted resources")
	check(w.enemies[0].get("curse_time",0)>0,"map reload preserves remaining curse")
	e=w.enemies[0];e["alive"]=false;e["hp"]=0;e["respawn_timer"]=.1;w.advance_respawns(1)
	check(e["alive"] and not e.has("mana") and not e.has("curse_time"),"respawn clears old debuffs and restores resource pools")
	for id in [38,56,58,59,304,314,315,361]:
		prepare(w,id);w.skills.cast(id);var state_copy: Dictionary=w.skills.serialize().duplicate(true);w.skills.restore(state_copy)
		check(not w.skills.active(w.skills.entry(id)["mode"]).is_empty(),"new buff survives save restore %d" % id)
	prepare(w,33);var old_count: int=int(w.inventory.get("1:1",0));w.drop_loot("1:1",Vector2(15.5,10.5))
	check(w.ground_loot.size()==1 and int(w.inventory.get("1:1",0))==old_count,"ranged loot remains on ground")
	w.remember_map();state=w.map_states[str(w.map_id)].duplicate(true);w.ground_loot=[];w.enemies=[];w.restore_map_state(state)
	check(w.ground_loot.size()==1,"uncollected loot survives map save restore")
	check(w.skills.cast(33) and w.ground_loot.is_empty() and int(w.inventory.get("1:1",0))==old_count+1,"Psycho Kinesis collects distant visible loot")
	w.collect_loot();check(int(w.inventory.get("1:1",0))==old_count+1,"collected loot cannot duplicate")
	w.skills.reset();w.drop_loot("1:1",Vector2(15.5,10.5));w.player=Vector2(15,10.5);w.collect_loot()
	check(w.ground_loot.is_empty() and int(w.inventory.get("1:1",0))==old_count+2,"walking near loot collects it")
	w.ground_loot=[];w.restore_map_state({"ground_loot":[{"key":"1:1","count":INF,"x":1,"y":1},{"key":"1:1","count":1,"x":[],"y":1}]})
	check(w.ground_loot.is_empty(),"invalid loot records are rejected")
	print("RESTORED EFFECTS: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
