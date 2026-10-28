extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func arena(w) -> void:
	w.enter_map(9);w.width=30;w.height=30;w.walkable=[]
	for i in range(900):w.walkable.append(1)
	w.player=Vector2(10.5,10.5);w.skills.reset();w.attack_cooldown=0;w.arrival_grace=100;w.enemies=[];w.rest_elapsed=0;w.stamina=2000;w.running=false
func prepare(w,id: int) -> void:
	arena(w);var row: Dictionary=w.skills.entry(id)
	w.character_id=int(row["hero"]);w.level=int(row["level"]);w.honor=int(row["honor"]);w.stats={"strength":100,"spirit":15000,"dexterity":100,"power":300};w.hp=w.max_hp();w.mana=w.max_mana();w.equipment={};w.weapon_bonus=0;w.armor_bonus=0
func enemy(w,x: float,y: float) -> Dictionary:
	var e: Dictionary={"monster_id":5,"hp":100000,"max_hp":100000,"alive":true,"x":x,"y":y,"cooldown":100.0};w.enemies.append(e);return e
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize();arena(w)
	check(w.rules.required_xp(1)==20 and w.rules.required_xp(2)==24 and w.rules.required_xp(3)==33,"original constructor's initial XP thresholds")
	check(w.rules.danger_max(123)==150 and w.rules.danger_max(10000)==666716 and w.rules.danger_max(10001)==666050,"DP formula includes original ten-thousand boundary")
	check(w.rules.special_attack(1)==50 and w.rules.special_attack(100)==1716,"original level-squared DP base damage")
	w.level=1;w.xp=0;w.bonus_points=0
	check(w.award_experience(999999)==2 and w.xp==2,"source ordinary solo award cap is one tenth of required XP")
	w.xp=19;w.hp=1;w.mana=0;w.award_experience(999)
	check(w.level==2 and w.xp==0 and w.bonus_points==2 and w.hp==w.max_hp() and w.mana==w.max_mana(),"level up resets XP, heals HP/MP and awards two points")
	w.level=99;w.xp=w.xp_required()-1;w.bonus_points=0;w.award_experience(999999999)
	check(w.level==100 and w.bonus_points==3,"native hundredth-level bonus retained")
	w.level=1000;w.xp=0;check(w.award_experience(999999)==0 and w.level==1000,"source level cap enforced")
	for id in [91,101,111,121,131,141,151,161,171]:
		prepare(w,id);enemy(w,11,10.5);w.danger=0
		check(not w.skills.cast(id),"DP special refuses an empty meter %d" % id)
		w.danger=w.max_danger();w.mana=0
		check(w.skills.assign(2,id) and w.skills.cast(id) and w.danger==0 and w.mana==0,"DP special uses full meter without MP %d" % id)
	prepare(w,91);w.danger=w.max_danger();var full: int=w.danger
	check(not w.skills.cast(91) and w.danger==full,"failed no-target DP cast keeps meter")
	var first: Dictionary=enemy(w,11,10.5);var second: Dictionary=enemy(w,12,10.5);w.skills.cast(91)
	check(first["hp"]==99963 and second["hp"]==99963,"area DP special hits both targets with original multiplier")
	prepare(w,131);first=enemy(w,11,10.5);second=enemy(w,12,10.5);w.danger=w.max_danger();w.skills.cast(131)
	check(first["hp"]<100000 and second["hp"]==100000,"single-target special does not become area damage")
	arena(w);w.hp=w.max_hp();w.danger=0;w.armor_bonus=0;w.receive_damage(7)
	check(w.danger==7,"taking damage fills DP")
	w.skills.buffs[13]={"mode":"mana_shield","remaining":10,"multiplier":75,"name":"fixture"};w.mana=10;w.receive_damage(7)
	check(w.danger==7,"fully absorbed damage grants no DP")
	w.skills.reset();w.danger=w.max_danger()-1;w.receive_damage(7);check(w.danger==w.max_danger(),"DP never exceeds source maximum")
	arena(w);w.hp=w.max_hp();w.armor_bonus=50;w.mana=100;var poison_hp: int=w.hp
	w.skills.buffs[13]={"mode":"mana_shield","remaining":10,"multiplier":75,"name":"fixture"}
	w.skills.apply_ailment("poison",6);w.skills.tick(.9);check(w.hp==poison_hp,"poison does not tick before a full second")
	var poison_save: Dictionary=w.skills.serialize().duplicate(true);w.skills.restore(poison_save)
	check(w.skills.poison_elapsed>0.89,"poison tick progress survives saving and loading")
	w.skills.tick(.11);check(w.hp==poison_hp-2*(w.max_hp()/100) and w.mana==100,"recovered poison ticks bypass armor and mana shields")
	w.skills.ailments.clear();poison_hp=w.hp;w.skills.tick(2);check(w.hp==poison_hp,"cleansing stops poison damage")
	prepare(w,73);w.skills.apply_ailment("poison",6);check(w.skills.cast(73) and not w.skills.ailments.has("poison"),"Sweet Water removes poison")
	prepare(w,55);w.skills.cast(55);check(not w.skills.apply_ailment("poison",6),"Mind Shield prevents poison")
	arena(w);var poisoner: Dictionary=enemy(w,11,10.5);check(w.monster_skills.cast(poisoner,190) and w.skills.ailments.has("poison"),"original poison monster entry casts through ordinary AI skill system")
	prepare(w,47);var hp_max: int=w.max_hp();w.skills.cast(47)
	check(w.effective_stat("power")==150 and w.max_hp()<hp_max and w.hp<=w.max_hp(),"Berserker halves base Power and clamps reduced HP")
	first=enemy(w,11,10.5);w.attack_cooldown=0;w.attack();check(first["hp"]==100000-2*w.basic_attack_power(),"Berserker doubles actual basic attacks")
	w.skills.tick(800);check(w.effective_stat("power")==300 and w.hp<w.max_hp(),"expiry restores capacity without free healing")
	for id in [18,75]:
		prepare(w,id);w.skills.cast(id);check(w.movement_dexterity()==3850 and w.effective_stat("dexterity")==100,"nimble Spirit/4 contribution does not bypass equipment requirements %d" % id)
	for id in [77,79]:
		prepare(w,id);w.skills.cast(id);check(is_equal_approx(w.skills.factor("attack_up"),1.2),"Lord of Wars source 20 percent attack contribution %d" % id)
	prepare(w,70);w.hp=1;w.mana=w.skills.cost(70);check(w.skills.cast(70) and w.hp==w.max_hp() and w.mana==w.max_mana(),"Hope self-cast restores both health and mana")
	prepare(w,372);check(w.skills.cast(372) and is_equal_approx(w.skills.basic_attack_delay(),.375),"Zyphyrus affects self attack rate")
	w.attack_cooldown=0;w.skills.cooldowns.clear();var mp: int=w.mana;check(not w.skills.cast(372) and w.mana==mp,"source active Zephyrus cannot be refreshed")
	prepare(w,64);mp=w.mana
	check(not w.skills.cast(64,Vector2(29.5,29.5)) and w.mana==mp,"Warp refuses destinations outside offline visible range")
	w.walkable[10*30+12]=0;check(not w.skills.cast(64,Vector2(12.5,10.5)) and w.mana==mp,"Warp refuses a blocked tile")
	w.walkable[10*30+12]=1;check(w.skills.cast(64,Vector2(12.5,10.5)) and w.player==Vector2(12.5,10.5),"Warp moves to a validated visible destination")
	for id in [25,45]:
		prepare(w,id);w.equipment={"weapon":"1:1" if id==25 else "1:83"};first=enemy(w,14.5,10.5);second=enemy(w,12.5,10.5);w.selected_enemy=first
		check(w.skills.cast(id) and w.player.x>10.5 and int(second["hp"])<100000,"rush moves and damages creatures along actual path %d" % id)
	prepare(w,90);first=enemy(w,11,10.5);w.skills.cast(90);var hp: int=w.hp;w.receive_damage(10,first)
	check(w.hp==hp-7,"exposure reduces incoming creature damage")
	w.damage_enemy(first,7);check(first["hp"]==99990,"exposure increases damage against weakened defense")
	prepare(w,332);first=enemy(w,11,10.5);w.skills.cast(332);w.arrival_grace=0;hp=w.hp;w.tick(.1,Vector2.ZERO)
	check(first["moving"] and w.hp==hp,"Chaos disorients creature movement and stops pursuit attacks")
	arena(w);w.character_id=1;w.hp=w.max_hp()-50;w.mana=0;w.stamina=1000;w.recover(10)
	check(w.stamina>1000 and w.hp==w.max_hp()-50,"rest restores stamina before health")
	w.stamina=2000;w.rest_elapsed=0;hp=w.hp;w.recover(10);check(w.hp==mini(w.max_hp(),hp+w.max_hp()/10) and w.mana==0,"rest recovers source ten percent HP before MP")
	w.hp=w.max_hp();w.recover(10);check(w.mana==w.max_mana()/10,"rest restores source ten percent mana after HP and SP")
	w.character_id=0;w.hp=w.max_hp()-200;hp=w.hp;w.recover(10);check(w.hp==mini(w.max_hp(),hp+2*(w.max_hp()/10)),"Philar receives recovered double health recovery")
	w.running=true;w.stamina=2000;w.rest_elapsed=0;w.player=Vector2(10.5,10.5)
	for i in range(3):w.tick(.1,Vector2.RIGHT)
	check(w.stamina<2000 and w.player.x>11.5,"run toggle spends SP on distance travelled")
	var path: String="user://recovered-systems.json";w.danger=42;w.stamina=1234;w.save_game(path)
	var copy=load("res://scripts/world.gd").new();copy.initialize();copy.load_game(path)
	check(copy.danger==42 and copy.stamina==1234,"DP and SP survive save/reload")
	var data: Dictionary=w.read_json(path);data.erase("progression_version");data["level"]=50;data["xp"]=1000
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close();copy.load_game(path)
	check(copy.level==50 and copy.xp==copy.xp_required()/2,"legacy XP migration preserves fractional level progress")
	w.create_character("Growth",1,path);w.bonus_points=2;check(w.allocate_stats({"spirit":1},path) and w.stats["spirit"]==28 and w.bonus_points==1,"Azlar spends one point for recovered eighteen Spirit")
	w.character_id=6;check(w.stat_gain("spirit")==12 and w.stat_gain("dexterity")==12,"Kitara uses original server class seven growth")
	w.character_id=7;check(w.stat_gain("spirit")==15 and w.stat_gain("dexterity")==13,"Lunarena uses original server class six growth")
	w.character_id=1;data=w.read_json(path);data.erase("attribute_growth_version");data["stats"]["spirit"]=12;data["bonus_points"]=5
	f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close();copy.load_game(path)
	check(copy.stats["spirit"]==46 and copy.bonus_points==5,"legacy adventure converts previously spent points once without consuming unspent points")
	copy.save_game(path);copy.load_game(path);check(copy.stats["spirit"]==46,"growth migration is idempotent")
	prepare(w,11);enemy(w,11,10.5);w.rest_elapsed=9;w.skills.cast(11);check(w.rest_elapsed==0,"casting interrupts the native recovery countdown")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute(path+suffix)
	print("RECOVERED SYSTEMS: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
