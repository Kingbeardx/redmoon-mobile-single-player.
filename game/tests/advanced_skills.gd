extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func prepare(w,id: int) -> Dictionary:
	var skill: Dictionary=w.skills.entry(id)
	w.character_id=int(skill["hero"]);w.level=int(skill["level"]);w.honor=int(skill["honor"]);w.stats["spirit"]=15000;w.mana=w.max_mana();w.hp=w.max_hp();w.skills.reset();w.attack_cooldown=0
	w.enemies=[{"monster_id":5,"x":w.player.x,"y":w.player.y,"hp":100000,"alive":true,"cooldown":0.0}]
	return w.enemies[0]
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize()
	var cases: Array=[[0,0,0],[0,1,-1],[0,-1,1],[0,101,-2],[0,-101,2],[0,1001,-10],[5,900,0],[-5,-900,0],[99,-300,100],[-99,300,-100],[550,-300,550],[-550,300,-550]]
	for c in cases:check(w.honor_after_kill(c[0],c[1])==c[2],"original honor arithmetic %s" % str(c))
	w.adventure_started=true;w.enter_map(0)
	check(w.enemies.any(func(e:Dictionary)->bool:return w.monster_reputation(int(e["monster_id"]))>0),"bounded population includes source positive-reputation faction")
	check(w.enemies.any(func(e:Dictionary)->bool:return w.monster_reputation(int(e["monster_id"]))<0),"bounded population includes source negative-reputation faction")
	w.honor=0;var enemy: Dictionary={"monster_id":153,"hp":1,"alive":true,"x":w.player.x,"y":w.player.y}
	w.damage_enemy(enemy,10);check(w.honor==1,"defeating original negative-reputation creature earns positive honor")
	w.damage_enemy(enemy,10);check(w.honor==1,"dead creature cannot award honor twice")
	enemy={"monster_id":103,"hp":1,"alive":true,"x":w.player.x,"y":w.player.y};w.damage_enemy(enemy,10);check(w.honor==0,"opposite faction moves honor toward neutral")
	w.map_states={};w.enemies=[{"monster_id":5,"hp":36,"alive":true,"x":w.player.x,"y":w.player.y}];w.remember_map();w.enter_map(9);w.enter_map(0)
	check(w.enemies.any(func(e:Dictionary)->bool:return w.monster_reputation(int(e["monster_id"]))!=0),"legacy neutral-only population gains original faction samples")
	w.enter_map(9);enemy=prepare(w,9);check(w.skills.cast(9) and enemy["sleep_time"]>0,"Sandman puts target to sleep")
	var hp: int=w.hp;w.tick(.1,Vector2.ZERO);check(w.hp==hp and not enemy["moving"],"sleep stops creature movement and attack")
	w.attack_cooldown=0;w.attack();check(enemy["sleep_time"]==0,"damage wakes sleeping creature")
	enemy=prepare(w,303);w.enemies.append({"monster_id":5,"hp":100000,"alive":true,"x":w.player.x,"y":w.player.y,"cooldown":0.0});check(w.skills.cast(303) and w.enemies.all(func(e:Dictionary)->bool:return e["sleep_time"]>0),"Morpheus applies area sleep")
	enemy=prepare(w,19);check(w.skills.cast(19) and enemy["freeze_time"]>0,"Cold Cell freezes target")
	hp=w.hp;w.tick(.1,Vector2.ZERO);check(w.hp==hp,"frozen target cannot strike")
	enemy=prepare(w,84);check(w.skills.cast(84) and enemy["blind_time"]>0,"Dark Curtain blinds target")
	hp=w.hp;w.tick(.1,Vector2.ZERO);check(w.hp==hp,"blinded target cannot land offline melee attack")
	enemy=prepare(w,27);w.equipment={"weapon":"1:1"};w.hp=1;check(w.skills.cast(27) and w.hp>1,"Vampiric Touch damages and heals caster")
	enemy=prepare(w,76);w.hp=1;enemy["hp"]=10;check(w.skills.cast(76) and w.hp==6,"Mistress Vampire heals 50% of actual damage, bounded on overkill")
	enemy=prepare(w,89);w.equipment={"weapon":"1:33"};check(w.skills.cast(89) and enemy["freeze_time"]>0 and enemy["hp"]<100000,"Ice Arrow damages and freezes")
	enemy=prepare(w,66);check(w.skills.cast(66) and enemy["blind_time"]>0,"Dark Sword damages and blinds")
	enemy=prepare(w,35);check(w.skills.cast(35) and not w.skills.active("fear_aura").is_empty(),"Horror applies fear aura")
	var path: String="user://advanced-skills.json";w.save_game(path)
	var restored=load("res://scripts/world.gd").new();restored.initialize();restored.load_game(path);check(not restored.skills.active("fear_aura").is_empty(),"fear aura survives save and reload")
	for id in [57,87]:
		enemy=prepare(w,id);check(w.skills.cast(id) and not w.skills.active("disguise").is_empty(),"invisibility variant casts %d" % id)
	var art: Dictionary=w.read_json("res://data/client-art.json")
	check(art.get("skill_projectiles",{}).size()>=20,"original projectile sequences decoded")
	var payloads: bool=true
	for group in art.get("skill_projectiles",{}).values():
		for frames in group.values():
			for key in frames:
				if key!="" and not art["images"].has(key):payloads=false
	check(payloads,"projectile references resolve, including transparent frames")
	w.enemies=[{"monster_id":5,"hp":0,"alive":false,"x":w.player.x,"y":w.player.y,"respawn_timer":0,"freeze_time":500,"blind_time":500}];w.advance_respawns(1)
	check(w.enemies[0]["alive"] and not w.enemies[0].has("freeze_time") and not w.enemies[0].has("blind_time"),"respawn clears status effects from previous life")
	for suffix in ["", ".bak"]:DirAccess.remove_absolute(path+suffix)
	print("ADVANCED SKILLS: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
