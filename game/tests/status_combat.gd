extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func monster(w,id: int=2) -> Dictionary:
	return {"monster_id":id,"x":w.player.x,"y":w.player.y,"hp":36,"max_hp":36,"alive":true,"cooldown":0.0}
func hero(w,id: int) -> void:
	var row: Dictionary=w.skills.entry(id);w.character_id=int(row["hero"]);w.level=int(row["level"]);w.honor=int(row["honor"]);w.stats["spirit"]=15000 if id in [16,311] else 300;w.hp=w.max_hp();w.mana=w.max_mana();w.skills.reset();w.attack_cooldown=0
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize();w.enter_map(9);w.arrival_grace=0
	check(w.monster_skills.catalog.size()==36,"all original monster skill entries catalogued")
	var e: Dictionary=monster(w);w.enemies=[e]
	for i in range(24):w.monster_skills.tick_enemy(e,.1)
	check(w.skills.ailments.is_empty(),"source 2500ms interval does not fire early")
	w.monster_skills.tick_enemy(e,.11);check(w.skills.ailments.has("root"),"monster AI casts source hold at its interval")
	check(w.skills.ailments["root"]<=3 and not w.skills.can_move(),"offline control duration bounded and movement blocked")
	var start: Vector2=w.player;w.tick(.1,Vector2.RIGHT);check(w.player==start,"rooted player cannot move through world tick")
	check(w.skills.can_act(),"root does not prevent attacks or cleansing")
	w.skills.tick(3.1);check(w.skills.ailments.is_empty() and w.skills.control_grace>0,"control expiry opens resistance window")
	check(not w.skills.apply_ailment("freeze",10),"resistance prevents immediate repeated control")
	w.skills.tick(2.1);check(w.skills.apply_ailment("freeze",10) and not w.skills.can_act(),"freeze blocks actions after resistance expires")
	var mana: int=w.mana;check(not w.attack(),"frozen character cannot basic attack")
	w.character_id=1;check(not w.skills.cast(11) and w.mana==mana,"frozen character cannot pay for offensive spell")
	hero(w,73);w.skills.apply_ailment("freeze",3);mana=w.mana
	check(w.skills.cast(73) and w.skills.ailments.is_empty() and w.mana==mana-400,"Sweet Water can cleanse while frozen and pays source cost")
	w.attack_cooldown=0;w.skills.cooldowns.clear();mana=w.mana
	check(not w.skills.cast(73) and w.mana==mana,"cleanse without ailment consumes no MP")
	hero(w,5);w.skills.apply_ailment("blind",5);check(w.skills.cast(5) and not w.skills.ailments.has("blind"),"Awakening removes blindness")
	hero(w,22);w.skills.apply_ailment("root",3);check(w.skills.cast(22) and w.skills.ailments.is_empty(),"Free Soul cleanses existing impairment")
	check(not w.skills.apply_ailment("root",3),"Free Soul prevents new impairment")
	check(is_equal_approx(float(w.skills.active("purify_guard")["remaining"]),5.0),"Free Soul uses recovered 200ms timer units")
	w.skills.tick(5.1);check(w.skills.apply_ailment("blind",5),"expired protection stops blocking impairment")
	for id in [55,85,311,16]:
		hero(w,id);check(w.skills.cast(id) and not w.skills.apply_ailment("blind",5),"protection skill blocks harmful effect %d" % id)
	hero(w,40);check(w.skills.cast(40),"Scarecrow casts")
	var hp: int=w.hp
	for i in range(3):w.receive_damage(10)
	check(w.hp==hp and w.skills.active("decoy").is_empty(),"Scarecrow blocks exactly three damaging hits")
	w.receive_damage(10);check(w.hp==hp-10,"fourth hit damages player")
	hero(w,40);w.skills.cast(40);w.attack_cooldown=0;w.skills.cooldowns.clear();mana=w.mana
	check(not w.skills.cast(40) and w.mana==mana,"active Scarecrow cannot be reset to free charges")
	w.receive_damage(10);var path: String="user://status-combat.json";w.skills.apply_ailment("slow",6);w.save_game(path)
	var restored=load("res://scripts/world.gd").new();restored.initialize();restored.load_game(path)
	check(int(restored.skills.active("decoy").get("charges",0))==2,"Scarecrow hit count survives save")
	check(restored.skills.ailments.has("slow"),"ailment timer survives save")
	restored.skills.restore({"saved_at":[],"ailments":{"root":"bad","freeze":INF,"invented":3},"buffs":{"40":{"remaining":50,"charges":[]}}})
	check(restored.skills.ailments.is_empty() and restored.skills.buffs.is_empty(),"malformed new optional state rejected safely")
	w.skills.reset();w.skills.apply_ailment("sleep",3);w.receive_damage(1)
	check(not w.skills.ailments.has("sleep") and w.skills.control_grace>0,"damage wakes player and grants short control resistance")
	w.skills.reset();hp=w.hp;check(w.monster_skills.cast(e,182) and w.hp==hp-10,"original monster physical skill multiplier used on offline base")
	e["blind_time"]=5;hp=w.hp;w.monster_skills.cast(e,182);check(w.hp==hp,"blind enemy cannot land a physical skill")
	e.erase("blind_time");e["hp"]=1;w.monster_skills.cast(e,183);check(e["hp"]>1 and e["hp"]<=36,"original monster heal restores bounded health")
	check(not w.monster_skills.cast(e,203),"summoning script not disguised as basic attack")
	var copy: Dictionary=monster(w);copy["x"]=w.player.x+50;hp=w.hp
	check(not w.monster_skills.cast(copy,184) and w.hp==hp,"monster skill cannot hit beyond source range")
	hero(w,43);check(w.skills.cast(43) and not w.skills.active("taunt").is_empty(),"Roar creates aggro aura")
	w.character_id=7;w.level=1000;w.stats={"strength":15000,"spirit":15000,"dexterity":15000,"power":15000}
	check(w.server_hero()==6 and w.equipment_reason("1:73")=="Equip now","Lunarena uses original server class bit for wands")
	w.character_id=6;check(w.server_hero()==7 and w.equipment_reason("1:73")=="Not for Kitara","Kitara cannot equip Lunarena's staff")
	w.inventory["1:73"]=1;w.equipment={"weapon":"1:73"};w.save_game(path);restored.load_game(path)
	check(restored.character_id==6 and int(restored.inventory.get("1:73",0))==1 and not restored.equipment.values().has("1:73"),"existing character identity and item retained when invalid old equipment is removed")
	w.armor_bonus=3;w.skills.reset();hp=w.hp;w.monster_skills.cast(e,182);check(w.hp==hp-7,"armor consistently reduces physical monster skill damage")
	check(w.monster_skills.engagement_distance(3)<1 and w.monster_skills.engagement_distance(5)>1,"melee spell caster closes within its actual casting range")
	w.width=10;w.height=10;w.walkable=[]
	for i in range(100):w.walkable.append(1)
	w.player=Vector2(5.5,5.5);w.skills.reset();w.armor_bonus=0;w.arrival_grace=0
	var melee: Dictionary=monster(w,3);melee["x"]=6.8;melee["cooldown"]=100;w.enemies=[melee];hp=w.hp
	for i in range(17):w.tick(.1,Vector2.ZERO)
	check(w.hp==hp-10,"world AI approaches and casts imported melee skill automatically")
	w.skills.reset();var holder: Dictionary=monster(w,2);holder["x"]=7.5;holder["cooldown"]=100;w.enemies=[holder]
	for i in range(27):w.tick(.1,Vector2.ZERO)
	check(w.skills.ailments.has("root"),"world AI applies source monster hold during ordinary updates")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute(path+suffix)
	print("STATUS COMBAT: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
