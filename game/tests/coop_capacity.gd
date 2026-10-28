extends SceneTree
var session
var w
var role: String
var elapsed: float=0
var finished: bool=false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if args.is_empty():print("COOP CAPACITY: external four-process integration");quit();return
	role=args[0];w=load("res://scripts/world.gd").new();w.initialize();w.create_character("Host" if role=="host" else role,1,"user://capacity.json");w.enter_map(9)
	session=load("res://scripts/coop_session.gd").new();session.name="Session";root.add_child(session);session.setup(w)
	var result: Error=session.host(24880) if role=="host" else session.join("127.0.0.1",24880)
	if result!=OK:push_error("Capacity transport failed");quit(1)
func _process(delta: float) -> bool:
	if session==null or finished:return false
	elapsed+=delta
	if elapsed>12:push_error("Capacity integration timed out");quit(1);return false
	if role=="host" and session.avatars.size()==3 and session.remote_views.size()==3:
		var names: Dictionary={}
		for guest in session.avatars.values():names[guest.player_name]=true
		if names.size()!=3:push_error("Guest identities collided");quit(1);return false
		finished=true;print("COOP CAPACITY HOST: 2 checks, 0 failures");create_timer(1.5).timeout.connect(close)
	elif role!="host" and session.is_client() and session.remote_views.size()==3:
		finished=true;print("COOP CAPACITY "+role+": 1 checks, 0 failures");create_timer(.75).timeout.connect(close)
	return false
func close() -> void:print("CAPACITY CLOSE ",role," ",Time.get_ticks_msec());session.stop();session.world=null;session.queue_free();w=null;quit()
