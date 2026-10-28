extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func arena(w) -> void:
	w.enter_map(9);w.width=30;w.height=30;w.walkable=[]
	for i in range(900):w.walkable.append(1)
	w.player=Vector2(10.5,10.5);w.enemies=[];w.skills.reset();w.party.allies=[];w.party.remote_allies=[];w.party.portal={};w.attack_cooldown=0;w.arrival_grace=0;w.complete_combat=false;w.hp=100;w.mana=10000000;w.armor_bonus=0;w.inventory={"4:1":5};w.equipment={}
func prepare(w,id: int) -> void:
	arena(w);var row: Dictionary=w.skills.entry(id);w.character_id=int(row["hero"]);w.level=1000;w.honor=int(row["honor"]);w.stats={"strength":1000,"spirit":15000,"dexterity":1000,"power":15000};w.hp=w.max_hp();w.mana=w.max_mana()
	if row["weapon"]!="":w.equipment={"weapon":"1:52"}
func enemy(w,id: int=56) -> Dictionary:
	var e: Dictionary={"monster_id":id,"x":11.5,"y":10.5,"hp":20,"max_hp":100,"alive":true,"cooldown":100.0,"respawn_seconds":60};w.enemies.append(e);return e
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize()
	for id in [15,28,301]:
		prepare(w,id);var before: int=w.mana;check(not w.skills.cast(id) and w.mana==before,"support fails without an ally and spends no MP")
		w.party.recruit(0);var ally: Dictionary=w.party.allies[0]
		if id==301:ally["hp"]=0
		elif id==15:ally["x"]=20
		elif id==28:ally["x"]=20
		var hp: int=w.hp;check(w.skills.cast(id),"support skill operates on actual ally %d" % id)
		if id==15:check(ally["x"]==w.player.x,"Recall moves recruited ally")
		if id==28:check(w.player.x>19,"Teleport moves to recruited ally")
		if id==301:check(ally["hp"]==hp/2 and w.hp==hp-hp/2 and w.mana==0,"Resurrection transfers half HP and all source MP")
	prepare(w,6);w.party.destination=w.map_id;var gate_mana: int=w.mana
	check(not w.skills.cast(6) and w.mana==gate_mana,"same-area gate is rejected without consuming MP")
	w.party.recruit(1);w.party.destination=0;check(w.skills.cast(6) and not w.party.portal.is_empty(),"Gate creates a genuine portal")
	check(w.party.use_gate() and w.map_id==0 and w.party.allies[0]["map"]==0,"Gate transports party")
	check(w.party.use_gate() and w.map_id==9,"Gate supports return journey")
	w.party.portal["until"]=0;check(not w.party.use_gate(),"expired gate cannot transport")
	var saved: Dictionary=w.party.serialize();w.party.restore(saved);check(w.party.allies.size()==1,"allies persist with health")
	w.party.restore({"allies":[{"hero":[],"hp":INF}]});check(w.party.allies.is_empty(),"malformed allies rejected")
	check(w.combat.hit_chance(100,100)==50 and w.combat.hit_chance(300,100)==75,"source base hit curve")
	check(w.combat.hit_chance(100,100,15)==65 and w.combat.hit_chance(100,100,0,1.2)==60,"Concentration and Rabbit Foot bonuses enter hit calculation")
	check(w.combat.mitigation(100,1000,10)==81,"replacement armor and Power mitigation")
	prepare(w,54);check(w.skills.cast(54) and not w.skills.active("concentration").is_empty(),"Concentration installs an accuracy buff")
	prepare(w,321);check(w.skills.cast(321) and not w.skills.active("luck").is_empty(),"Rabbit Foot installs an accuracy buff")
	for id in [191,192,194,195,201,203,204,205,206,207,208,211]:
		arena(w);var e: Dictionary=enemy(w);var old_count: int=w.enemies.size()
		if id==204:e["freeze_time"]=3.0
		check(w.monster_skills.cast(e,id),"reconstructed monster effect casts %d" % id)
		if id in [191,201]:
			check(int(w.inventory["4:1"])==4 and int(e.get("stolen",{}).get("4:1",0))==1,"theft records recoverable loot")
			w.damage_enemy(e,100000);check(w.inventory["4:1"]==5,"defeating thief restores stolen item")
		if id in [203,205]:check(w.enemies.size()==old_count+1,"summoning adds a real creature")
		if id==206:check(e["hp"]>20,"linked healer restores creature HP")
		if id==204:check(not e.has("freeze_time"),"linked cleanser removes creature impairment")
		if id in [192,194]:check(e.get("stealth_time",0)>0,"stealth installs expiring concealment")
	arena(w);w.story.flags=127;check(w.campaign.start(),"continuation starts after recovered chapter")
	for stage in range(7):
		var destination: int=int(w.campaign.current()["map"]);check(w.travel_to(destination),"campaign destination is playable %d" % destination)
		var fights: Array=w.enemies.filter(func(e:Dictionary)->bool:return int(e.get("campaign_id",-1))==stage)
		check(fights.size()==int(w.campaign.current()["count"]),"campaign creates required encounter")
		for e in fights:w.damage_enemy(e,100000000)
		check(w.campaign.report,"objective progresses to report")
		check(w.travel_to(75),"return to Kasham")
		check(w.campaign.finish(),"report advances continuation")
	check(w.campaign.completed and w.honor_cap()==1000,"complete Earth-to-Signus ending and final honor cap")
	var campaign_save: Dictionary=w.campaign.serialize();w.campaign.restore(campaign_save);check(w.campaign.completed,"completed ending survives restore")
	print("RECONSTRUCTION: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
