extends SceneTree
const World=preload("res://scripts/world.gd")
var failures: int=0
var checks: int=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(label)
func _initialize() -> void:
	var w=World.new()
	check(w.initialize() and w.item_metadata.size()==784,"source item metadata loaded")
	check(w.item_name("1:1")=="Oak Sword","localized name")
	w.inventory={"1:1":1,"2:1":1,"4:1":2}
	w.character_id=1
	w.use_item("1:1")
	check(w.equipment.is_empty(),"Azlar cannot equip source-restricted sword")
	w.character_id=2
	w.use_item("1:1")
	check(w.weapon_bonus==5 and w.equipment["7"]=="1:1","Sadad equips sword in source slot")
	w.use_item("2:1")
	check(w.armor_bonus==5 and w.equipment["2"]=="2:1","source armor defense and slot")
	w.hp=1
	w.use_item("4:1")
	check(w.hp==w.max_hp() and w.inventory["4:1"]==1,"source food restores 1000 HP up to current maximum")
	w.stats["power"]=99
	w.stats["spirit"]=99
	w.bonus_points=2
	check(w.allocate_stat("power") and w.max_hp()==127,"allocated Power applies recovered HP formula")
	check(w.allocate_stat("spirit") and w.max_mana()==120,"allocated Spirit applies recovered MP formula")
	check(not w.allocate_stat("strength"),"cannot spend unavailable points")
	var key: String=""
	for candidate in w.item_metadata:
		if candidate.begins_with("4:") and int(w.item_metadata[candidate]["mp"])>0:
			key=candidate;break
	w.inventory[key]=1
	w.mana=0
	w.use_item(key)
	check(w.mana==mini(w.max_mana(),int(w.item_metadata[key]["mp"])) and w.inventory[key]==0,"source drink restores MP")
	var path: String="user://recovered-items-test.json"
	w.save_game(path)
	var restored=World.new()
	restored.initialize()
	check(restored.load_game(path) and restored.stats==w.stats and restored.equipment==w.equipment and restored.weapon_bonus==5,"stats and slotted gear persist")
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(path+".bak")
	w.level=1;w.xp=w.xp_required()-1;w.bonus_points=0;w.attack_cooldown=0
	w.enemies=[{"monster_id":1,"x":w.player.x,"y":w.player.y,"hp":1,"alive":true}]
	w.attack()
	check(w.level==2 and w.bonus_points==2,"ordinary level gives recovered two points")
	w.level=99;w.xp=w.xp_required()-1;w.bonus_points=0;w.attack_cooldown=0
	w.enemies=[{"monster_id":1,"x":w.player.x,"y":w.player.y,"hp":1,"alive":true}]
	w.attack()
	check(w.level==100 and w.bonus_points==3,"hundredth level gives recovered three points")
	print("RECOVERED ITEMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
