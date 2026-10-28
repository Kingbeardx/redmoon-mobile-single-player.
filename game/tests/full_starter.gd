extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _initialize() -> void:
	for hero in range(9):
		var w=load("res://scripts/world.gd").new();w.initialize();w.save_path_override="user://full-starter.json";w.create_character("Starter%d" % hero,hero);w.set_combat_mode(true);w.combat.random.seed=910+hero;w.doctor_service();w.travel_to(1);w.travel_to(0)
		check(w.enemies.size()==3 and w.enemies.all(func(e:Dictionary)->bool:return int(e["monster_id"])==7),"fresh hero reaches appropriate starter creatures %d" % hero)
		for step in range(1500):
			if w.tutorial_stage>=3 or w.map_id!=0:break
			if w.hp<w.max_hp()/2:w.heal()
			var target: Dictionary={};var distance: float=INF
			for enemy in w.enemies:
				if not bool(enemy.get("alive",false)):continue
				var d: float=w.player.distance_to(Vector2(enemy["x"],enemy["y"]))
				if d<distance:distance=d;target=enemy
			var movement:=Vector2.ZERO
			if not target.is_empty():
				var goal:=Vector2(target["x"],target["y"])
				if distance>=w.weapon_range()-.15 or not w.clear_sight(w.player,goal):
					var path: Array[Vector2i]=w.navigation.get_id_path(Vector2i(w.player.floor()),Vector2i(goal.floor()))
					if path.size()>1:goal=Vector2(path[1])+Vector2(.5,.5)
					movement=w.player.direction_to(goal)
				else:w.attack()
			w.tick(.1,movement)
		check(w.tutorial_stage==3 and w.map_id==0,"fresh full-rules hero wins training with ordinary controls %d" % hero)
		w.travel_to(9);w.doctor_service();check(w.tutorial_stage==4,"fresh hero returns to complete Doctor training %d" % hero)
	print("FULL STARTER: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
