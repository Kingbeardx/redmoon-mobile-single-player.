extends SceneTree
const World=preload("res://scripts/world.gd")
var checks: int=0
var failures: int=0
var path: String="user://new-adventure-check.json"
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1;push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var w=World.new();w.initialize()
	check(not w.create_character("A",0,path),"reject invalid character name")
	check(not w.create_character("Hero",9,path),"reject nonexistent class")
	check(w.create_character("NewHero",2,path),"create named Sadad")
	check(w.player_name=="NewHero" and w.character_id==2 and w.level==1,"character identity and level")
	check(w.stats=={"strength":10,"spirit":10,"dexterity":10,"power":10} and w.hp==50 and w.mana==50,"recovered initial attributes and health")
	check(w.map_id==9 and w.enemies.is_empty() and w.can_stand(w.player),"safe hospital start on walkable tile")
	check(w.inventory["4:1"]==5 and w.inventory["5:93"]==1,"source starter food and map")
	w.interact()
	check(w.tutorial_stage==1 and w.gold==50 and w.armor_bonus==5 and w.weapon_bonus>0,"doctor grants one-time class-compatible beginner supplies")
	w.interact()
	check(w.gold==50,"doctor introduction reward cannot repeat")
	check(w.travel_to(1) and w.tutorial_stage==2,"visit named Street 1 advances introduction")
	check(w.map_name()=="Street 1" and w.travel_to(0),"travel to named Backyard")
	check(w.enemies.any(func(e: Dictionary) -> bool: return Vector2(float(e["x"]),float(e["y"])).distance_to(w.player)<25),"source spawns provide nearby beginner combat")
	for i in range(3):
		w.enemies=[{"monster_id":1,"x":w.player.x,"y":w.player.y,"hp":1,"alive":true}]
		w.attack_cooldown=0;w.attack()
	check(w.tutorial_stage==3 and w.tutorial_kills==3,"Backyard defeats complete training objective")
	check(w.travel_to(9),"return to hospital")
	w.player=w.find_start([9,12]);w.interact()
	check(w.tutorial_stage==4 and w.gold==165,"complete training and receive reward")
	w.interact();check(w.gold==165,"training reward cannot repeat")
	check(w.travel_to(4) and w.deposit_gold() and w.bank_gold==165 and w.gold==0,"bank deposit")
	check(w.withdraw_gold() and w.gold==165 and w.bank_gold==0,"bank withdrawal")
	w.travel_to(5);check(not w.deposit_gold(),"bank unavailable outside bank")
	check(not w.zone_stock().is_empty(),"food shop has recovered stock")
	w.save_game(path)
	var restored=World.new();restored.initialize()
	check(restored.load_game(path) and restored.player_name=="NewHero" and restored.tutorial_stage==4 and restored.visited.has(9),"identity, objective and discoveries survive reload")
	var malformed: Dictionary=restored.read_json(path);malformed["visited"]="invalid"
	check(not restored.valid_save(malformed),"invalid discovery data rejected")
	# Exercise every hero's valid equipment selection.
	for hero in range(9):
		w.create_character("Hero%d" % hero,hero,path);w.interact()
		check(w.armor_bonus==5 and w.character_id==hero,"starter equipment supports hero %d" % hero)
	# Defeat recovery returns to the safe hospital without losing identity.
	w.travel_to(0);w.hp=0;w.tick(0.01,Vector2.ZERO)
	check(w.map_id==9 and w.hp==w.max_hp(),"defeat recovers at hospital")
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(path+suffix)
	print("NEW ADVENTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
