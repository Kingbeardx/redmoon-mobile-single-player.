extends Node
## Offline music library, independent of gameplay pause and character saves.
var scene: Node
var player: AudioStreamPlayer
var tracks: Array=[]
var map_tracks: Dictionary={}
var enabled: bool=true
var volume: float=70.0
var index: int=0
var last_map: int=-1
var manual: bool=false
var status: String=""
var poll: float=0.0
var saved_map: int=-1
var saved_track: String=""
const SETTINGS="user://audio.cfg"

func setup(owner_scene: Node) -> void:
	scene=owner_scene
	var library=scene.world.read_json("res://data/music.json")
	if library is Dictionary:
		tracks=library.get("tracks",[]);map_tracks=library.get("map_tracks",{})
	if tracks.is_empty():tracks=[{"id":"001","name":"Client music","path":"art/music.oggdata"}]
	var options:=ConfigFile.new()
	if options.load(SETTINGS)==OK:
		enabled=bool(options.get_value("audio","music_enabled",true))
		volume=clampf(float(options.get_value("audio","music_volume",70)),0,100)
		scene.sounds_enabled=bool(options.get_value("audio","sounds_enabled",true))
		manual=bool(options.get_value("audio","manual",false))
		saved_map=int(options.get_value("audio","map",-1));saved_track=str(options.get_value("audio","track",""))
	if AudioServer.get_bus_index("Music")==-1:
		AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"Music")
	player=AudioStreamPlayer.new();player.bus="Music";player.volume_db=linear_to_db(maxf(0.0001,volume/100))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),volume<=0)
	add_child(player);player.finished.connect(_finished)
	scene.music=player;scene.music_enabled=enabled
	set_map(scene.world.map_id)

func find_track(id: String) -> int:
	for i in range(tracks.size()):
		if str(tracks[i].get("id",""))==id:return i
	return 0

func set_map(id: int) -> void:
	if id==last_map:return
	last_map=id
	if manual and saved_map==id and not saved_track.is_empty():index=find_track(saved_track)
	else:
		manual=false;index=find_track(str(map_tracks.get(str(id),"001")))
	if enabled:play_selected()

func title() -> String:
	return str(tracks[index].get("name","Client music")) if not tracks.is_empty() else "Music unavailable"

func play_selected() -> bool:
	if not enabled:return false
	for attempt in range(tracks.size()):
		var path: String=str(tracks[index].get("path",""))
		if not path.begins_with("art/") or ".." in path: index=(index+1)%tracks.size();continue
		if not FileAccess.file_exists("res://"+path):index=(index+1)%tracks.size();continue
		var data:=FileAccess.get_file_as_bytes("res://"+path)
		if data.size()<4 or data.slice(0,4).get_string_from_ascii()!="OggS":index=(index+1)%tracks.size();continue
		var stream:=AudioStreamOggVorbis.load_from_buffer(data)
		if stream==null:index=(index+1)%tracks.size();continue
		stream.loop=manual or map_tracks.has(str(last_map))
		player.stream=stream;player.volume_db=linear_to_db(maxf(0.0001,volume/100));player.play()
		status="Playing "+title();return true
	status="Music files could not be loaded."
	return false

func toggle() -> void:
	enabled=not enabled;scene.music_enabled=enabled
	if enabled:play_selected()
	else:player.stop();status="Music off"
	save_settings()

func set_volume(value: float) -> void:
	volume=clampf(value,0,100);player.volume_db=linear_to_db(maxf(.0001,volume/100))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),volume<=0);save_settings()

func next_track(direction: int=1) -> void:
	index=posmod(index+direction,tracks.size());manual=true
	if enabled:play_selected()
	save_settings()

func _finished() -> void:
	if not enabled:return
	index=(index+1)%tracks.size();play_selected()

func save_settings() -> void:
	var options:=ConfigFile.new()
	options.set_value("audio","music_enabled",enabled);options.set_value("audio","music_volume",volume)
	options.set_value("audio","sounds_enabled",scene.sounds_enabled);options.set_value("audio","track",str(tracks[index].get("id","001")))
	options.set_value("audio","map",last_map);options.set_value("audio","manual",manual);options.save(SETTINGS)

func _process(delta: float) -> void:
	poll+=delta
	if poll<1.0 or player==null:return
	poll=0
	if enabled and player.stream!=null and not player.playing and not player.stream_paused:player.play()
