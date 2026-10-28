extends SceneTree
var session
var w
var elapsed: float=0
var role: String=""
var initial: Vector2
var requested: bool=false
var moved: bool=false
var checks: int=0
var failed: bool=false
var finishing: bool=false
var phase: int=0
var saw_fallen: bool=false
var last_attack: float=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failed=true;push_error(text)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	role=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "skip"
	if role=="skip":print("COOP TRANSPORT: standalone host/client integration uses tools/test_coop_transport.py");quit();return
	w=load("res://scripts/world.gd").new();w.initialize();w.create_character("Host" if role=="host" else "NetGuest",1,"user://net-test.json");w.enter_map(9);w.enemies=[];w.player=w.find_start([9,12]);w.complete_combat=false
	if role=="host":
		w.character_id=int(w.skills.entry(301)["hero"]);w.level=1000;w.honor=int(w.skills.entry(301)["honor"]);w.stats["spirit"]=15000;w.stats["power"]=15000;w.hp=w.max_hp();w.mana=w.max_mana()
	if role=="host":w.enemies=[{"monster_id":7,"x":w.player.x,"y":w.player.y,"hp":10000,"max_hp":10000,"alive":true,"cooldown":100.0}]
	session=load("res://scripts/coop_session.gd").new();session.name="Session";root.add_child(session);session.setup(w)
	check((session.host(24879) if role=="host" else session.join("127.0.0.1",24879))==OK,"ENet initializes")
	initial=w.player
func _process(delta: float) -> bool:
	if session==null or finishing:return false
	elapsed+=delta
	if elapsed>12:check(false,"network scenario timed out");finish();return false
	if role=="host":
		if session.avatars.size()>0:
			var guest=session.avatars.values()[0]
			if guest.player.distance_to(initial)>.1:moved=true
			if phase==0 and w.enemies[0]["hp"]<10000:
				check(moved,"remote movement reaches host simulation")
				check(w.enemies[0]["hp"]<=9988 and guest.attack_cooldown>0,"remote attack changes host-owned enemy health")
				check(guest.stats["strength"]==10,"host rejects invalid remote stat spending")
				check(guest.party.allies.size()==1,"remote companion recruitment is host-owned")
				w.player=initial+Vector2(10,0)
				check(w.combat_target(w.enemies[0])==guest,"host AI chooses a nearer live guest")
				phase=1;guest.hp=0;w.player=guest.player
				create_timer(.35).timeout.connect(func():
					var before: int=w.hp;session.request("skill",301);w.set_combat_mode(true)
					check(guest.hp>0 and w.hp==before-before/2,"host Resurrection revives an actual connected player")
					w.level=50;w.xp=0;guest.xp=0;w.campaign.stage=0;w.campaign.kills=0;w.campaign.report=false;w.enemies[0]["campaign_id"]=0;phase=2)
		if phase==2 and w.campaign.report:
			check(w.xp>0 and session.avatars.values()[0].xp>0,"nearby host and guest share actual kill XP")
			check(w.campaign.report,"guest kill advances host campaign")
			print("HOST_ACK");finishing=true;create_timer(1).timeout.connect(finish)
	elif session.is_client() and w.enemies.size()>0:
		session.client_direction=Vector2.ZERO if saw_fallen else Vector2(.3,0)
		if not requested and elapsed>.8:
			session.command.rpc_id(1,"recruit",0);session.command.rpc_id(1,"stats",{"strength":999999});session.act.rpc_id(1,"skill",301,0);session.move.rpc_id(1,Vector2(20,0));session.request("attack");requested=true
		if w.hp==0:saw_fallen=true;session.client_direction=Vector2.ZERO
		if requested and saw_fallen and w.hp>0 and not w.campaign.report:
			if elapsed-last_attack>.55:session.request("attack");last_attack=elapsed
		if requested and saw_fallen and w.hp>0 and w.campaign.report:
			check(w.player.distance_to(initial)>.1,"authoritative position snapshot returns to client")
			check(w.enemies[0]["hp"]<=9988,"authoritative attack snapshot returns to client")
			check(w.party.allies.size()==1,"authoritative companion state returns to client")
			check(saw_fallen and w.hp>0,"fallen guest receives Resurrection from host")
			check(w.complete_combat,"host combat-rule changes synchronize to guests")
			check(w.campaign.report and w.xp>0,"shared campaign and XP snapshots reach the guest")
			finish()
	return false
func finish() -> void:
	print("COOP "+role.to_upper()+": %d checks, %d failures" % [checks,1 if failed else 0]);session.stop();session.world=null;session.queue_free();w=null;quit(1 if failed else 0)
