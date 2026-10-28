extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize();w.enter_map(9)
	check(w.rules.strength_attack(0)==8,"source zero Strength attack")
	check(w.rules.strength_attack(10)==10,"source starting Strength attack")
	check(w.rules.strength_attack(999)==287,"source low segment truncates floating result")
	check(w.rules.strength_attack(1000)==295,"source cubic segment begins at 1000")
	check(w.rules.strength_attack(10000)==285724,"source cubic segment includes 10000")
	check(w.rules.strength_attack(10001)==285724,"source second segment truncates each division")
	check(w.rules.strength_attack(13000)==627724,"source linear segment begins at 13000")
	w.level=1;w.stats["strength"]=10;w.equipment={};w.weapon_bonus=0
	check(w.basic_attack_power()==12,"starting character retains playable offline base")
	w.stats["strength"]=100;check(w.basic_attack_power()==38,"Strength raises effective basic attack power")
	var enemy: Dictionary={"monster_id":5,"x":w.player.x,"y":w.player.y,"hp":10000,"max_hp":10000,"alive":true};w.enemies=[enemy];w.attack_cooldown=0;w.skills.reset()
	check(w.attack() and enemy["hp"]==9962,"world applies Strength growth to actual attack")
	w.character_id=2;w.level=1000;w.honor=int(w.skills.entry(26)["honor"]);w.equipment={"weapon":"1:1"};w.stats["spirit"]=15000;w.mana=w.max_mana();w.attack_cooldown=0;enemy["hp"]=10000
	var expected: int=int(w.basic_attack_power()*int(w.skills.entry(26)["multiplier"])/100)
	check(w.skills.cast(26) and enemy["hp"]==10000-expected,"weapon skill uses Strength-derived attack")
	print("STRENGTH COMBAT: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
