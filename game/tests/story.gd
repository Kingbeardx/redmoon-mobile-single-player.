extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func npc_for(w,role: String) -> Dictionary:
	for npc in w.story.data["npcs"]:
		if npc["story_role"]==role:return npc
	return {}
func boss(w,id: int) -> Dictionary:
	for enemy in w.enemies:
		if int(enemy["monster_id"])==id:return enemy
	return {}
func _initialize() -> void:
	var w=load("res://scripts/world.gd").new();w.initialize();w.create_character("StoryHero",1,"user://story-character.json")
	check(not w.story.active() and w.honor_cap()==100,"new character does not bypass original level gate")
	w.level=49;w.xp=w.xp_required()-1;w.story.update();check(not w.story.active(),"story remains locked at level 49")
	var defeated: Dictionary={"monster_id":5,"hp":1,"alive":true,"x":w.player.x,"y":w.player.y};w.damage_enemy(defeated,10)
	check(w.level==50 and w.story.has(1),"ordinary combat reaching level fifty starts original story")
	check(w.travel_options().has(74) and not w.travel_options().has(75),"story guide unlocks destinations in order")
	check(w.travel_to(74),"guide reaches preserved Spy house")
	check(w.enemies.size()==3 and w.enemies.filter(func(e:Dictionary)->bool:return int(e["monster_id"])==90).size()==1,"quest room respects original one-Spy and two-guard quantities")
	var spy: Dictionary=boss(w,90);check(not spy.is_empty() and spy["max_hp"]==2000,"Spy encounter uses documented offline boss health")
	spy["hp"]=1700;var path: String="user://story-save.json";w.save_game(path)
	var restored=load("res://scripts/world.gd").new();restored.initialize();restored.load_game(path)
	check(boss(restored,90)["hp"]==1700 and boss(restored,90)["max_hp"]==2000,"boss health is preserved across save and reload")
	w.damage_enemy(spy,10000);check(w.story.has(2) and w.honor_cap()==200 and int(w.inventory.get("5:1",0))==1,"Spy victory grants Microfilm and original first cap flag")
	w.damage_enemy(spy,10000);check(int(w.inventory.get("5:1",0))==1,"dead boss cannot duplicate Microfilm")
	var gold: int=w.gold;w.shop_available=true;w.sell_item("5:1");check(int(w.inventory["5:1"])==1 and w.gold==gold,"quest Microfilm cannot be sold")
	var archeologist: Dictionary=npc_for(w,"archeologist");check(not w.story.finish(archeologist,0),"distant NPC cannot complete quest")
	w.travel_to(37);check(w.story.can_talk(archeologist),"quest guide arrives near actual Archeologist coordinates")
	check(not w.story.finish(archeologist,0,"user://missing-story-directory/fail.json") and w.story.has(2) and not w.story.has(4) and int(w.inventory["5:1"])==1,"failed save rolls back consumed quest item and flags")
	check(w.story.finish(archeologist,1) and int(w.inventory["5:1"])==0 and not w.story.has(4),"original wrong-answer branch confiscates Microfilm")
	w.travel_to(74);check(boss(w,90)["alive"] and boss(w,90)["hp"]==2000,"lost-film retry resets spent one-shot encounter")
	w.damage_enemy(boss(w,90),10000);w.travel_to(37)
	check(w.story.finish(archeologist,0) and w.story.has(4) and int(w.inventory["5:1"])==0,"correct Street1 answer decodes Microfilm exactly once")
	check(not w.story.finish(archeologist,0),"decoded film cannot be submitted twice")
	var geographer: Dictionary=npc_for(w,"geographer");w.travel_to(29);w.honor=100
	var separated: bool=true;var positions: Array=[]
	for npc in w.content["npcs"]:
		if int(npc["map_id"])!=29:continue
		var pos: Vector2=w.npc_position(npc);var b: Dictionary=npc["bounds"]
		if pos.x<float(b["left"]) or pos.x>float(b["right"]) or pos.y<float(b["top"]) or pos.y>float(b["bottom"]):separated=false
		for prior in positions:
			if pos.distance_to(prior)<3:separated=false
		positions.append(pos)
	check(separated,"NPCs sharing roaming bounds receive distinct positions within original rectangles")
	var geo_pos: Vector2=w.npc_position(geographer);w.enter_map(9);w.travel_to(29)
	check(w.npc_position(geographer)==geo_pos,"NPC positions stay deterministic across map reloads")
	check(w.story.finish(geographer) and w.honor_cap()==300 and w.honor==130,"Geographer grants cap 300 and original thirty absolute honor")
	var after: int=w.honor;check(not w.story.finish(geographer) and w.honor==after,"Geographer reward is one-time")
	var kasham: Dictionary=npc_for(w,"kasham");w.travel_to(75)
	check(w.story.finish(kasham) and w.story.has(16) and w.travel_options().has(72),"Kasham accepts Esper mission and unlocks dungeon guide")
	w.map_states["72"]={"player":[10.5,20.5],"enemies":[{"monster_id":12,"hp":36,"alive":true,"x":10.5,"y":20.5}]}
	w.travel_to(72);check(not boss(w,92).is_empty(),"legacy dungeon population gains required quest Esper")
	check(boss(w,92)["max_hp"]==3500,"Esper has persistent encounter health")
	defeated={"monster_id":12,"hp":1,"alive":true,"x":w.player.x,"y":w.player.y};w.damage_enemy(defeated,10)
	check(not w.story.has(32),"ordinary Esper does not satisfy the special quest target")
	w.damage_enemy(boss(w,92),10000);check(w.story.has(32) and w.honor_cap()==300,"Esper victory requires return before cap reward")
	w.travel_to(75);check(w.story.finish(kasham) and w.story.complete() and w.honor_cap()==400,"reporting victory completes recovered chapter and raises cap")
	check(w.honor==180 and int(w.inventory.get("5:102",0))==1,"Kasham grants original fifty absolute honor and Sahara1 Map")
	check(not w.story.finish(kasham) and int(w.inventory["5:102"])==1,"final reward cannot be repeated")
	w.save_game(path);restored.load_game(path)
	check(restored.story.complete() and restored.honor_cap()==400 and restored.honor==180,"chapter flags, honor and cap persist")
	w.honor=-100;w.story.increase_abs_honor(30);check(w.honor==-130,"original absolute reward preserves negative alignment")
	w.honor=0;w.story.increase_abs_honor(50);check(w.honor==0,"original quest reward does not choose alignment for neutral player")
	w.story.restore({"flags":8});check(w.story.flags==1 and w.honor_cap()==100,"impossible optional quest flags cannot bypass prerequisites")
	w.story.restore({"flags":[]});check(w.story.flags==1,"malformed optional story state loads safely")
	for name in [path,"user://story-character.json"]:
		for suffix in ["", ".bak"]:DirAccess.remove_absolute(name+suffix)
	print("STORY: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
