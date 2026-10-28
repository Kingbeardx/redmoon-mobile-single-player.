extends RefCounted
## Authored continuation using recovered locations and late-story dialogue.
## These objectives replace missing programs; they are not original quest scripts.
const MISSIONS=[
	{"map":71,"monster":90,"count":1,"title":"Earth Commander","brief":"Kasham's informer identifies the Boss Spy in Sahara 2. Break Aguilas' network on Earth."},
	{"map":86,"monster":41,"count":1,"title":"The Hidden Memory","brief":"Follow the recovered lead into the Himalayan caverns. Defeat the guardian and recover your lost memory."},
	{"map":88,"monster":53,"count":2,"title":"The Spaceship","brief":"Clear the boarding robots so the damaged ship can leave Earth."},
	{"map":93,"monster":64,"count":3,"title":"Arrival on Signus","brief":"Establish a safe landing zone for the survivors."},
	{"map":94,"monster":65,"count":3,"title":"Break the Siege","brief":"Defeat the occupation troops and reopen the route through Signus."},
	{"map":95,"monster":67,"count":2,"title":"The Enemy's Signal","brief":"Silence the officers directing Aguilas' defenses."},
	{"map":96,"monster":56,"count":1,"title":"The Last Stand","brief":"Confront Aguilas' manifestation and end this reconstructed campaign."}
]
var owner_ref: WeakRef
var world:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var stage: int=-1
var kills: int=0
var report: bool=false
var completed: bool=false
func setup(w) -> void:owner_ref=weakref(w)
func start() -> bool:
	if not world.story.complete() or stage>=0:return false
	stage=0;kills=0;report=false;completed=false;world.save_game();return true
func current() -> Dictionary:return MISSIONS[stage] if stage>=0 and stage<MISSIONS.size() else {}
func title() -> String:
	if completed:return "Campaign complete · Signus is free"
	if stage<0:return "Continuation unlocks after Kasham's first chapter"
	return str(current()["title"])+(" · Report to Kasham" if report else " · %d/%d" % [kills,current()["count"]])
func destination() -> int:return 75 if report else int(current().get("map",75))
func ensure_encounter() -> void:
	if stage<0 or completed or report or world.map_id!=int(current().get("map",-1)):
		var stale: bool=world.enemies.any(func(enemy:Dictionary)->bool:return enemy.has("campaign_id") or enemy.has("scaled_encounter"))
		if stale:world.enemies=[];world.spawn_enemies()
		return
	world.enemies=world.enemies.filter(func(enemy:Dictionary)->bool:return int(enemy.get("campaign_id",-1))==stage or int(enemy.get("scaled_encounter",-1))==stage)
	var existing: int=0
	for enemy in world.enemies:
		if int(enemy.get("campaign_id",-1))==stage and bool(enemy.get("alive",false)):existing+=1
	var needed: int=int(current()["count"])-kills-existing
	for index in range(needed):
		if world.enemies.size()>=world.MAX_ENEMIES:world.enemies.pop_front()
		var point: Vector2=world.find_start([int(world.player.x)+4+index,int(world.player.y)+4])
		if world.navigation!=null and world.navigation.get_id_path(Vector2i(world.player.floor()),Vector2i(point.floor())).is_empty():point=world.player
		var id: int=int(current()["monster"]);var hp: int=maxi(300,world.basic_attack_power()*(25+stage*8)/maxi(1,int(current()["count"]))) if world.complete_combat else world.story.encounter_hp(id)
		world.enemies.append({"monster_id":id,"name":current()["title"],"campaign_id":stage,"x":point.x,"y":point.y,"hp":hp,"max_hp":hp,"alive":true,"cooldown":2.0,"respawn_seconds":2000000000})
func defeat(enemy: Dictionary) -> void:
	if stage<0 or completed or report or int(enemy.get("campaign_id",-1))!=stage:return
	kills+=1
	if kills>=int(current()["count"]):report=true;world.message="Mission complete. Return to Kasham to report."
	world.save_game()
func finish() -> bool:
	if not report or world.map_id!=75:return false
	var npc: Dictionary=world.nearest_npc()
	if world.story.role(npc)!="kasham":world.message="Move closer to Kasham to report.";return false
	var prior: Dictionary=serialize();var gold: int=world.gold;var honor: int=world.honor;var progress: Dictionary=world.story.progress_checkpoint()
	world.gold+=100*(stage+1);world.award_experience(world.xp_required()/2)
	world.honor=signi(world.honor if world.honor!=0 else 1)*mini(1000,absi(world.honor)+50)
	stage+=1;kills=0;report=false;completed=stage>=MISSIONS.size()
	if world.save_game()!=OK:restore(prior);world.gold=gold;world.honor=honor;world.story.restore_progress(progress);return false
	world.message=title();return true
func serialize() -> Dictionary:return {"stage":stage,"kills":kills,"report":report,"completed":completed}
func restore(saved: Variant) -> void:
	stage=-1;kills=0;report=false;completed=false
	if not saved is Dictionary or not world.valid_number(saved.get("stage")):return
	stage=clampi(int(saved["stage"]),-1,MISSIONS.size());completed=stage==MISSIONS.size()
	if stage>=0 and not completed:
		kills=clampi(int(saved.get("kills",0)) if world.valid_number(saved.get("kills")) else 0,0,int(current()["count"]));report=kills>=int(current()["count"])
