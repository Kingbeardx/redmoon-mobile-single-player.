extends Node
## Real ENet LAN co-op. Host owns movement, combat, drops and skill validation.
## Trusted local save import is allowed; there is no public account service.
var world
var peer: ENetMultiplayerPeer
var api: SceneMultiplayer
var avatars: Dictionary={}
var directions: Dictionary={}
var remote_views: Array=[]
var status: String="Offline"
var send_elapsed: float=0
var connecting: bool=false
var client_direction:=Vector2.ZERO
var error_text: String=""
var next_enemy_id: int=1
const PORT=24838
var refresh_ui: bool=false
var pending_refresh: bool=false
func setup(w) -> void:world=w;world.network_session=weakref(self)
func active() -> bool:return peer!=null and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED
func is_client() -> bool:return active() and not api.is_server()
func start_api() -> void:
	api=SceneMultiplayer.new();api.server_relay=false;get_tree().set_multiplayer(api,get_path());api.multiplayer_peer=peer
	api.peer_disconnected.connect(disconnected_peer)
	api.connected_to_server.connect(connected)
	api.connection_failed.connect(failed)
	api.server_disconnected.connect(failed)
func host(port: int=PORT) -> Error:
	stop();peer=ENetMultiplayerPeer.new();var result: Error=peer.create_server(port,3)
	if result!=OK:peer=null;status="Host failed: %d" % result;return result
	start_api();world.coop_active=true;status="Hosting LAN co-op · UDP %d" % port;return OK
func join(address: String,port: int=PORT) -> Error:
	stop();peer=ENetMultiplayerPeer.new();var result: Error=peer.create_client(address.strip_edges(),port)
	if result!=OK:peer=null;status="Connection failed: %d" % result;return result
	connecting=true;start_api();status="Connecting…";return OK
func stop() -> void:
	var old_peer: ENetMultiplayerPeer=peer
	peer=null
	if api!=null:
		api.multiplayer_peer=null
		if is_inside_tree():get_tree().set_multiplayer(null,get_path())
		api=null
	if old_peer!=null:old_peer.close()
	avatars.clear();directions.clear();remote_views=[];connecting=false
	if world!=null:world.coop_active=false;world.party.remote_allies=[]
	status="Offline"

func failed() -> void:
	stop();status="Disconnected · Check host address, LAN and UDP port."
	world.message=status
	if world.save_game()!=OK:world.message+=" Progress could not be saved."
func disconnected_peer(id: int) -> void:
	avatars.erase(id);directions.erase(id)
func profile(w) -> Dictionary:
	return {"name":w.player_name,"hero":w.character_id,"level":w.level,"honor":w.honor,"stats":w.stats.duplicate(),"inventory":w.inventory.duplicate(),"equipment":w.equipment.duplicate(),"gold":w.gold,"xp":w.xp,"bonus_points":w.bonus_points,"party":w.party.serialize(),"sig_gold":w.sig_gold,"bank_gold":w.bank_gold,"tutorial_stage":w.tutorial_stage,"tutorial_kills":w.tutorial_kills,"shop_available":w.shop_available,"defeated":w.defeated}
func connected() -> void:
	connecting=false;hello.rpc_id(1,profile(world));world.coop_active=true;status="Connected · Host controls area travel";world.message=status
@rpc("any_peer","call_remote","reliable")
func hello(data: Dictionary) -> void:
	if not api.is_server():return
	var id: int=api.get_remote_sender_id()
	if avatars.has(id) or avatars.size()>=3:return
	var guest=load("res://scripts/world.gd").new()
	if not guest.initialize():return
	if not guest.valid_number(data.get("hero")):return
	guest.save_path_override="user://lan-session-%d.json" % id
	guest.create_character(str(data.get("name","Guest")).strip_edges().left(14),clampi(int(data["hero"]),0,8),"user://lan-session-%d.json" % id)
	for key in ["level","honor","gold","sig_gold","bank_gold","xp","bonus_points","tutorial_stage","tutorial_kills","defeated"]:
		if guest.valid_number(data.get(key)):guest.set(key,clampi(int(data[key]),-1000 if key=="honor" else 0,1000 if key in ["level","honor"] else 1000000000))
	guest.level=maxi(1,guest.level);guest.tutorial_stage=clampi(guest.tutorial_stage,0,4)
	var stats: Variant=data.get("stats",{})
	if stats is Dictionary:
		for key in ["strength","spirit","dexterity","power"]:
			if guest.valid_number(stats.get(key)):guest.stats[key]=clampi(int(stats[key]),1,1000000)
	guest.inventory={};var items: Variant=data.get("inventory",{})
	if items is Dictionary and items.size()<=1000:
		for key in items:
			if guest.item_metadata.has(str(key)) and guest.valid_number(items[key]):guest.inventory[str(key)]=clampi(int(items[key]),0,100000)
	guest.equipment={};var gear: Variant=data.get("equipment",{})
	if gear is Dictionary and gear.size()<=16:
		for slot in gear:
			var key: String=str(gear[slot])
			if int(guest.inventory.get(key,0))>0 and guest.equipment_reason(key)=="Equip now":guest.equipment[str(slot)]=key
	guest.refresh_equipment();guest.party.restore(data.get("party",{}))
	guest.network_session=weakref(self)
	guest.complete_combat=world.complete_combat;guest.enter_map(world.map_id);guest.player=world.player;guest.hp=guest.max_hp();guest.mana=guest.max_mana();guest.coop_active=true
	avatars[id]=guest;directions[id]=Vector2.ZERO;status="Hosting · %d player(s)" % (avatars.size()+1)
@rpc("any_peer","call_remote","unreliable_ordered")
func move(direction: Vector2,running: bool=false) -> void:
	if not api.is_server() or not direction.is_finite() or direction.length()>1.1:return
	var id: int=api.get_remote_sender_id()
	if avatars.has(id):directions[id]=direction.limit_length(1);avatars[id].running=running
@rpc("any_peer","call_remote","reliable")
func act(kind: String,id: int=0,ally_index: int=0,target_id: int=-1) -> void:
	if not api.is_server():return
	var sender: int=api.get_remote_sender_id()
	if avatars.has(sender):
		avatars[sender].party.selected=clampi(ally_index,0,4)
		for enemy in world.enemies:
			if int(enemy.get("net_id",-2))==target_id and bool(enemy.get("alive",false)):avatars[sender].selected_enemy=enemy;break
		perform(avatars[sender],kind,id)
func request(kind: String,id: int=0) -> void:
	if not active():return
	if is_client():act.rpc_id(1,kind,id,world.party.selected,int(world.selected_enemy.get("net_id",-1)))
	else:perform(world,kind,id)
func bind_allies(w) -> void:
	w.party.remote_allies=[]
	var peers: Dictionary=avatars.duplicate();peers[1]=world
	for id in peers:
		var other=peers[id]
		if other==w or other.map_id!=w.map_id:continue
		w.party.remote_allies.append({"peer":id,"name":other.player_name,"hero":other.character_id,"appearance":other.server_hero(),"hp":other.hp,"initial_hp":other.hp,"max_hp":other.max_hp(),"map":other.map_id,"x":other.player.x,"y":other.player.y,"initial_x":other.player.x,"initial_y":other.player.y})
func commit_allies(w) -> void:
	for ally in w.party.remote_allies:
		var other=world if int(ally["peer"])==1 else avatars.get(int(ally["peer"]))
		if other==null:continue
		var delta_hp: int=int(ally["hp"])-int(ally["initial_hp"])
		if delta_hp!=0:other.hp=clampi(other.hp+delta_hp,0,other.max_hp());ally["initial_hp"]=ally["hp"]
		if float(ally["x"])!=float(ally["initial_x"]) or float(ally["y"])!=float(ally["initial_y"]):other.player=other.find_start([int(ally["x"]),int(ally["y"])]);ally["initial_x"]=ally["x"];ally["initial_y"]=ally["y"]
func perform(w,kind: String,id: int) -> void:
	if w.hp<=0 and kind!="respawn":return
	bind_allies(w)
	match kind:
		"attack":w.attack()
		"heal":w.heal()
		"food":w.quick_food()
		"skill":
			if w.skills.cast(id) and w.skills.entry(id).get("mode","")=="gate":world.party.portal=w.party.portal.duplicate()
		"gate":
			world.party.portal=w.party.portal.duplicate();world.party.use_gate()
		"warp":pass # Ground targeting is sent through the separately validated RPC.
		"respawn":
			if w.hp<=0:w.player=w.find_start([9,12]);w.hp=w.max_hp();w.mana=w.max_mana();w.arrival_grace=5
	commit_allies(w)
@rpc("any_peer","call_remote","reliable")
func warp(point: Vector2) -> void:
	if not api.is_server() or not point.is_finite():return
	var id: int=api.get_remote_sender_id()
	if avatars.has(id):avatars[id].skills.cast(64,point)
func views(except_world=null) -> Array:
	var rows: Array=[];var peers: Dictionary=avatars.duplicate();peers[1]=world
	for id in peers:
		var w=peers[id]
		if w==except_world:continue
		rows.append({"peer":id,"name":w.player_name,"hero":w.character_id,"appearance":w.server_hero(),"hp":w.hp,"max_hp":w.max_hp(),"x":w.player.x,"y":w.player.y,"map":w.map_id,"moving":w.motion.length_squared()>.01,"facing":w.facing,"action_remaining":w.action_remaining,"action_duration":w.action_duration})
	return rows
func _process(delta: float) -> void:
	if not active():return
	var dt: float=minf(.1,maxf(0,delta));send_elapsed+=dt
	if is_client():
		if send_elapsed>=.08:move.rpc_id(1,client_direction.limit_length(1),world.running);send_elapsed=0
		return
	commit_allies(world)
	for enemy in world.enemies:
		if not enemy.has("net_id"):enemy["net_id"]=next_enemy_id;next_enemy_id+=1
	for id in avatars:
		var guest=avatars[id]
		if guest.map_id!=world.map_id:guest.enter_map(world.map_id);guest.player=world.player;guest.party.regroup()
		guest.complete_combat=world.complete_combat;guest.enemies=world.enemies;guest.ground_loot=world.ground_loot
		guest.attack_cooldown=maxf(0,guest.attack_cooldown-dt)
		if guest.hp>0:guest.recover(dt)
		var shared: Array=guest.enemies;guest.enemies=[];guest.skills.tick(dt);guest.enemies=shared
		guest.arrival_grace=maxf(0,guest.arrival_grace-dt)
		guest.action_remaining=maxf(0,guest.action_remaining-dt)
		var direction: Vector2=directions.get(id,Vector2.ZERO)
		if guest.hp<=0 or not guest.skills.can_move():direction=Vector2.ZERO
		if guest.skills.ailments.has("slow"):direction*=.5
		guest.motion=direction
		if direction.length_squared()>.001:guest.facing=guest.facing_for(direction)
		var prior_position: Vector2=guest.player
		guest.player=guest.move_entity(guest.player,direction*guest.MOVE_SPEED*dt*maxf(guest.skills.factor("haste"),1.2 if not guest.skills.active("zephyrus").is_empty() else 1)*(1.6 if guest.running and guest.stamina>0 else 1))
		if guest.running and guest.stamina>0:
			guest.run_distance+=prior_position.distance_to(guest.player)
			while guest.run_distance>=1:
				guest.run_distance-=1;guest.run_steps+=1;guest.stamina=maxi(0,guest.stamina-int(250.0/sqrt(maxi(1,guest.movement_dexterity()))+.5));guest.rest_elapsed=0
		guest.party.tick(dt);guest.collect_loot()
	bind_allies(world);remote_views=views(world)
	if send_elapsed<.1:return
	send_elapsed=0
	for id in avatars:
		if not api.get_peers().has(id):continue
		var connection: ENetPacketPeer=peer.get_peer(id)
		if connection==null or connection.get_state()!=ENetPacketPeer.STATE_CONNECTED or connection.get_channels()<1:continue
		var guest=avatars[id];bind_allies(guest)
		var all_effects: Array=world.skills.effects.duplicate()
		for other in avatars.values():all_effects.append_array(other.skills.effects)
		var snapshot: Dictionary={"complete_combat":world.complete_combat,"message":guest.message,"server_time":Time.get_unix_time_from_system(),"effects":all_effects.slice(0,100),"action_remaining":guest.action_remaining,"action_duration":guest.action_duration,"story_flags":world.story.flags,"campaign":world.campaign.serialize(),"map":world.map_id,"enemies":world.enemies,"loot":world.ground_loot,"position":[guest.player.x,guest.player.y],"hp":guest.hp,"mana":guest.mana,"danger":guest.danger,"stamina":guest.stamina,"profile":profile(guest),"skills":guest.skills.serialize(),"players":views(guest),"allies":guest.party.remote_allies}
		state.rpc_id(id,snapshot)
@rpc("authority","call_remote","reliable")
func state(snapshot: Dictionary) -> void:
	if api.is_server():return
	if world.complete_combat!=bool(snapshot["complete_combat"]):world.set_combat_mode(bool(snapshot["complete_combat"]))
	var map: int=int(snapshot["map"])
	if world.map_id!=map:world.enter_map(map)
	world.message=str(snapshot.get("message","Connected"))
	world.story.flags=int(snapshot["story_flags"]);world.campaign.restore(snapshot["campaign"])
	var selected_id: int=int(world.selected_enemy.get("net_id",-1));world.enemies=snapshot["enemies"];world.selected_enemy={}
	for enemy in world.enemies:
		if int(enemy.get("net_id",-2))==selected_id and bool(enemy.get("alive",false)):world.selected_enemy=enemy;break
	world.ground_loot=snapshot["loot"];world.player=Vector2(snapshot["position"][0],snapshot["position"][1])
	for key in ["hp","mana","danger","stamina"]:world.set(key,int(snapshot[key]))
	if world.hp<=0:world.message="FALLEN · Ask an ally to resurrect you, or JOURNEY → LAN CO-OP → RESPAWN."
	var data: Dictionary=snapshot["profile"]
	for key in ["level","honor","gold","xp","bonus_points","stats","inventory","equipment","tutorial_stage","tutorial_kills","shop_available","defeated","bank_gold","sig_gold"]:world.set(key,data[key])
	world.refresh_equipment();var skill_state: Dictionary=snapshot["skills"];skill_state["saved_at"]=Time.get_unix_time_from_system();world.skills.restore(skill_state);world.skills.effects=snapshot["effects"];world.action_remaining=float(snapshot["action_remaining"]);world.action_duration=float(snapshot["action_duration"])
	var portal: Dictionary=data["party"].get("portal",{})
	if not portal.is_empty():portal["until"]=float(portal["until"])+Time.get_unix_time_from_system()-float(snapshot["server_time"])
	var selected: int=world.party.selected;world.party.restore(data["party"]);world.party.selected=selected;world.party.remote_allies=snapshot["allies"];remote_views=snapshot["players"]
	if pending_refresh:refresh_ui=true;pending_refresh=false

@rpc("any_peer","call_remote","reliable")
func command(kind: String,payload: Variant) -> void:
	if not api.is_server():return
	var id: int=api.get_remote_sender_id()
	if not avatars.has(id):return
	var guest=avatars[id]
	if guest.hp<=0:return
	match kind:
		"quick_food":guest.quick_food()
		"item":
			if payload is String and payload.length()<30:guest.use_item(payload)
		"unequip":
			if payload is String:
				for slot in guest.equipment.keys():
					if guest.equipment[slot]==payload:guest.equipment.erase(slot)
				guest.refresh_equipment()
		"buy":
			if payload is String and payload.length()<50 and guest.shop_available:guest.buy_stock(payload)
		"sell":
			if payload is String and payload.length()<30:guest.sell_item(payload)
		"exchange":guest.exchange_sig_gold()
		"deposit":guest.deposit_gold()
		"withdraw":guest.withdraw_gold()
		"travel":guest.message="The host leads area travel. Use a party gate to travel together."
		"bind":
			if payload is Dictionary and guest.valid_number(payload.get("slot")) and guest.valid_number(payload.get("id")):guest.skills.assign(int(payload["slot"]),int(payload["id"]))
		"stats":
			if payload is Dictionary and payload.size()<=4:guest.allocate_stats(payload)
		"npc":
			if payload is Dictionary and payload.size()<=3:
				for npc in guest.content.get("npcs",[]):
					if npc.get("map_id")==payload.get("map") and npc.get("event_id")==payload.get("event") and npc.get("name")==payload.get("name"):guest.interact_with(npc);break
		"recruit":
			if guest.valid_number(payload):guest.party.recruit(int(payload))
		"dismiss":
			if guest.valid_number(payload) and int(payload)>=0 and int(payload)<guest.party.allies.size():guest.party.allies.remove_at(int(payload))
		"rally":guest.party.regroup()
		"destination":
			if guest.valid_number(payload) and guest.travel_options().has(int(payload)):guest.party.destination=int(payload)
	guest.save_game()
	command_result.rpc_id(id,guest.message)
@rpc("authority","call_remote","reliable")
func command_result(message: String) -> void:
	world.message=message;pending_refresh=true
