extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize();w.create_character("Combat",1,"user://combat-replacement.json");w.enter_map(9)
	w.enemies=[{"monster_id":7,"x":w.player.x,"y":w.player.y,"hp":18,"max_hp":36,"alive":true,"cooldown":100.0}]
	w.ground_loot=[{"key":"1:1","count":1,"x":w.player.x+5,"y":w.player.y}];w.remember_map();w.map_states["4"]={"player":[9,12],"ground_loot":[{"key":"1:1","count":1,"x":9.5,"y":12.5}],"enemies":[]}
	w.set_combat_mode(true)
	check(w.enemies[0]["max_hp"]==50 and w.enemies[0]["hp"]==25,"mode migration preserves monster health fraction")
	check(w.ground_loot.size()==1 and w.map_states["4"]["ground_loot"].size()==1,"combat migration preserves saved loot")
	check(w.combat.monster_health(w,90)==26650 and w.combat.monster_health(w,92)==81600,"source Constitution health arithmetic")
	check(w.combat.minimum_attack(100,100)==75 and w.combat.minimum_attack(300,100)==38,"source minimum damage curve")
	w.stats={"strength":100,"spirit":100,"dexterity":100,"power":300};w.hp=w.max_hp();w.mana=w.max_mana();w.level=100;w.honor=0
	check(w.spell_attack_power()>12+(w.level-1)*2,"Spirit contributes to psychic damage")
	w.stats["spirit"]=1000;check(w.spell_attack_power()>400,"psychic damage grows with Spirit allocation")
	var enemy: Dictionary=w.enemies[0];enemy["monster_id"]=7;enemy["hp"]=100000;enemy["max_hp"]=100000
	w.combat.random.seed=919;var before: int=enemy["hp"];var misses: int=0
	for i in range(100):
		w.attack_cooldown=0;var prior: int=enemy["hp"];w.attack()
		if enemy["hp"]==prior:misses+=1
	check(misses>0 and enemy["hp"]<before,"replacement basic attack has real hits and misses")
	w.stats["dexterity"]=1000;enemy["monster_id"]=5;var ordinary: int=0;var focused: int=0
	w.combat.random.seed=100
	for i in range(1000):
		if w.combat.player_hit(w,enemy):ordinary+=1
	w.skills.buffs[54]={"mode":"concentration","remaining":20,"multiplier":100,"name":"Concentration"};w.skills.buffs[321]={"mode":"luck","remaining":20,"multiplier":120,"name":"Rabbit Foot"};w.stats["dexterity"]=1000
	w.combat.random.seed=100
	for i in range(1000):
		if w.combat.player_hit(w,enemy):focused+=1
	check(focused>ordinary,"Dexterity and accuracy skills improve actual attack success")
	w.hp=0;w.rest_elapsed=9;w.recover(20);check(w.hp==0,"fallen players cannot regenerate themselves alive")
	w.hp=w.max_hp();w.party.recruit(0);var path: String="user://combat-replacement-save.json";check(w.save_game(path)==OK,"replacement model saves")
	var restored=load("res://scripts/world.gd").new();restored.initialize();check(restored.load_game(path) and restored.complete_combat and restored.party.allies.size()==1,"combat choice and recruited allies restore")
	w.gold=0;w.sig_gold=0;w.grant_source_drop({"kind":5,"index":0,"count":1234},w.player);w.grant_source_drop({"kind":5,"index":2,"count":567},w.player)
	check(w.gold==1234 and w.sig_gold==567,"native money and Signus money item IDs map to wallets")
	check(not w.inventory.has("5:0") and not w.inventory.has("5:2"),"currency drops do not become unusable bag items")
	w.stats={"strength":10+3*w.stat_gain("strength"),"spirit":10+2*w.stat_gain("spirit"),"power":10,"dexterity":10};w.bonus_points=4;w.inventory["6:67"]=1;w.use_item("6:67")
	check(w.stats["strength"]==10 and w.stats["spirit"]==10 and w.bonus_points==9,"source Poison Pill returns spent class-growth points")
	check(w.inventory["6:67"]==0,"attribute reset consumes one pill")
	w.travel_to(4)
	for npc in w.content["npcs"]:
		if int(npc.get("map_id",-1))==4 and str(npc.get("name","")).trim_prefix("+")=="BankClerk":w.player=w.npc_position(npc);break
	check(w.exchange_sig_gold() and w.gold==1801 and w.sig_gold==0,"reconstructed exchange converts credits at a real banker")
	print("COMBAT REPLACEMENT: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
