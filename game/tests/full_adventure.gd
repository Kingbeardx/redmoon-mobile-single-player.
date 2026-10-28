extends SceneTree
var w
var checks: int=0
var failures: int=0
var food_hp: String=""
var food_mp: String=""
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func supplies() -> void:
	w.inventory[food_hp]=100;w.inventory[food_mp]=100;w.potions=5;w.hp=w.max_hp();w.mana=w.max_mana();w.skills.reset();w.attack_cooldown=0
	w.party.allies=[];w.party.recruit(0);w.party.recruit(7)
func fight_until(done: Callable) -> bool:
	var area: int=w.map_id
	for step in range(3600):
		if done.call():return true
		if w.hp<=0 or w.map_id!=area:print("BATTLE DEBUG death/map",w.hp," map",w.map_id," expected",area," foes",w.enemies.size());return false
		if w.hp<w.max_hp()*3/4 or w.mana<700:
			if not w.quick_food() and w.hp<w.max_hp()/2:w.heal()
		if w.skills.active("purify_guard").is_empty() and w.skills.requirement(22)=="Ready":w.skills.cast(22)
		var target: Dictionary={};var distance: float=INF
		for enemy in w.enemies:
			if not bool(enemy.get("alive",false)):continue
			var d: float=w.player.distance_to(Vector2(enemy["x"],enemy["y"]))
			if d<distance:distance=d;target=enemy
		var movement:=Vector2.ZERO
		if not target.is_empty():
			if distance>=w.weapon_range()-.15 or not w.clear_sight(w.player,Vector2(target["x"],target["y"])):
				var goal:=Vector2(target["x"],target["y"])
				if not w.clear_sight(w.player,goal) and w.navigation!=null:
					var path: Array[Vector2i]=w.navigation.get_id_path(Vector2i(w.player.floor()),Vector2i(goal.floor()))
					if path.size()>1:goal=Vector2(path[1])+Vector2(.5,.5)
				movement=w.player.direction_to(goal)
			else:w.selected_enemy=target;w.attack()
		if int(w.inventory.get(food_hp,0))<=0:
			for drop in w.ground_loot:
				if drop["key"]!=food_hp:continue
				var goal:=Vector2(drop["x"],drop["y"])
				if not w.clear_sight(w.player,goal) and w.navigation!=null:
					var path: Array[Vector2i]=w.navigation.get_id_path(Vector2i(w.player.floor()),Vector2i(goal.floor()))
					if path.size()>1:goal=Vector2(path[1])+Vector2(.5,.5)
				movement=w.player.direction_to(goal);break
		w.tick(.1,movement)
	if not done.call():print("BATTLE DEBUG timeout HP",w.hp," position",w.player," foes",w.enemies.size()," flags",w.story.flags," boss",w.enemies.filter(func(e:Dictionary)->bool:return int(e["monster_id"])==92))
	return done.call()
func _initialize() -> void:
	# A legal level-400 Sadad fixture: all 798 earned points are allocated
	# through the real source class-growth API. Combat uses ordinary input
	# actions; no direct damage injection or invulnerability is used.
	w=load("res://scripts/world.gd").new();w.initialize();w.save_path_override="user://full-adventure.json";w.create_character("FullRules",2);w.level=400;w.bonus_points=798
	check(w.allocate_stats({"strength":330,"power":240,"dexterity":180,"spirit":48}),"advanced fixture obeys earned point budget")
	w.set_combat_mode(true);w.combat.random.seed=41078;w.inventory["1:1"]=1;w.use_item("1:1")
	var best_hp: int=0;var best_mp: int=0
	for key in w.item_metadata:
		if not str(key).begins_with("4:"):continue
		var item: Dictionary=w.item_metadata[key]
		if int(item.get("hp",0))<1000000000 and int(item.get("hp",0))>best_hp:best_hp=int(item["hp"]);food_hp=key
		if int(item.get("mp",0))<1000000000 and int(item.get("mp",0))>best_mp:best_mp=int(item["mp"]);food_mp=key
	check(not food_hp.is_empty() and not food_mp.is_empty(),"source supplies exist for advanced combat")
	w.story.update();w.travel_to(74);supplies()
	check(fight_until(func()->bool:return w.story.has(2)),"full combat defeats source-health Spy and guards")
	var archeologist: Dictionary={};var geographer: Dictionary={};var kasham: Dictionary={}
	for npc in w.story.data["npcs"]:
		match npc["story_role"]:
			"archeologist":archeologist=npc
			"geographer":geographer=npc
			"kasham":kasham=npc
	w.travel_to(37);check(w.story.finish(archeologist,0),"full-rules film decode")
	w.travel_to(29);check(w.story.finish(geographer),"full-rules map mission")
	w.travel_to(75);check(w.story.finish(kasham),"full-rules Esper assignment")
	w.travel_to(72);supplies();check(fight_until(func()->bool:return w.story.has(32)),"full combat defeats source-health Esper")
	w.travel_to(75);check(w.story.finish(kasham) and w.story.complete(),"first chapter completes with full combat")
	check(w.campaign.start(),"reconstructed continuation follows the original chapter")
	for stage in range(7):
		w.travel_to(w.campaign.destination());supplies()
		check(fight_until(func()->bool:return w.campaign.report),"full-rules battle completes mission %d" % stage)
		w.travel_to(75);check(w.campaign.finish(),"full-rules report advances mission %d" % stage)
	check(w.campaign.completed,"advanced playable adventure reaches its ending")
	print("FULL ADVENTURE: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
