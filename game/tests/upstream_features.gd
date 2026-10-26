extends SceneTree
const World=preload("res://scripts/world.gd")
var failures: int=0
var checks: int=0
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(label)
func _initialize() -> void:
	var w=World.new()
	check(w.initialize(),"world initialization")
	check(w.facing_for(Vector2(1,-1))==9 and w.facing_for(Vector2(-1,1))==1,"source keypad directions")
	var art: Dictionary=w.read_json("res://data/client-art.json")
	check(art["actor_states"]["0"]["idle"].size()==8,"hero zero has eight idle directions")
	check(art["actor_states"]["1"]["walk"].size()==8,"hero one has eight walking directions")
	check(art["object_animations"].size()>0,"animated object frames imported")
	var sound=AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes("res://art/attack.wavdata"))
	check(sound!=null and sound.get_length()>0,"original attack sound decodes")
	var track=AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://art/music.oggdata"))
	check(track!=null and track.get_length()>1,"client MIDI soundtrack decodes")
	check(art["actors"].has("14"),"original NPC appearance is present")
	var synthetic=World.new()
	synthetic.width=5;synthetic.height=3;synthetic.map_id=0
	synthetic.walkable=[0,0,0,0,0,0,1,0,1,0,0,0,0,0,0]
	synthetic.player=Vector2(1.5,1.5)
	synthetic.enemies=[{"monster_id":1,"x":3.5,"y":1.5,"hp":36,"alive":true}]
	check(not synthetic.clear_sight(synthetic.player,Vector2(3.5,1.5)),"wall blocks sight")
	check(not synthetic.attack() and synthetic.enemies[0]["hp"]==36,"attack cannot pass through wall")
	# Real client rectangle + source-documented map destination semantics.
	var rect: Dictionary=w.exits["1"][0]
	w.enter_map(1)
	w.player=Vector2((float(rect["left"])+float(rect["right"]))/96.0,(float(rect["top"])+float(rect["bottom"]))/48.0)
	var expected: int=-1
	for event in w.content["events"]:
		if int(event.get("map_id",-1))==1 and int(event["id"])==int(rect["id"]) and int(event["type"])==1:
			expected=int(event["args"][0])
	check(expected>=0,"client exit matches an original warp event")
	check(w.use_exit() and w.map_id==expected and w.can_stand(w.player),"actual map exit travels to traversable destination")
	var maze=World.new()
	maze.map_id=0;maze.width=5;maze.height=5
	maze.walkable=[0,0,0,0,0,0,1,1,1,0,0,1,0,1,0,0,1,1,1,0,0,0,0,0,0]
	maze.navigation=AStarGrid2D.new()
	maze.navigation.region=Rect2i(0,0,5,5)
	maze.navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	maze.navigation.update()
	for y in range(5):
		for x in range(5):
			if not maze.is_open(Vector2i(x,y)):
				maze.navigation.set_point_solid(Vector2i(x,y))
	maze.player=Vector2(3.5,2.5)
	maze.enemies=[{"monster_id":1,"x":1.5,"y":2.5,"hp":36,"max_hp":36,"cooldown":100.0,"alive":true}]
	for tick in range(150):
		maze.tick(0.1,Vector2.ZERO)
	var enemy=Vector2(float(maze.enemies[0]["x"]),float(maze.enemies[0]["y"]))
	check(maze.clear_sight(enemy,maze.player) and enemy.distance_to(maze.player)<2,"enemy routes around intervening wall")
	print("UPSTREAM FEATURES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
