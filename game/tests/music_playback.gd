extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,text: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(text)
func _initialize() -> void:call_deferred("run")
func peak(buffer: PackedVector2Array) -> float:
	var result: float=0
	for frame in buffer:result=maxf(result,maxf(absf(frame.x),absf(frame.y)))
	return result
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame
	var audio=scene.audio_controller
	check(scene.music_enabled and scene.music.playing,"music starts by default even at title")
	check(audio.tracks.size()==48,"all 48 existing client MIDI tracks included")
	check(audio.volume==70,"audible default volume")
	scene.frontend.close_for_play();scene.set_process(false)
	var capture:=AudioEffectCapture.new();capture.buffer_length=3
	AudioServer.add_bus_effect(0,capture)
	audio.index=audio.find_track("013");audio.manual=true;audio.play_selected()
	await create_timer(1.5).timeout
	var captured:=capture.get_buffer(capture.get_frames_available())
	check(captured.size()>1000 and peak(captured)>.005,"decoded music reaches the actual mixer with audible PCM samples")
	audio.set_volume(0);await create_timer(.3).timeout;capture.clear_buffer();await create_timer(.35).timeout
	check(peak(capture.get_buffer(capture.get_frames_available()))<.00001,"zero volume truly mutes mixed output")
	audio.set_volume(60);capture.clear_buffer();await create_timer(.5).timeout
	check(peak(capture.get_buffer(capture.get_frames_available()))>.003,"raising volume restores mixed audio")
	scene.toggle_music();check(not scene.music_enabled and not scene.music.playing,"music can be switched off")
	var options:=ConfigFile.new();options.load("user://audio.cfg")
	check(not bool(options.get_value("audio","music_enabled",true)) and float(options.get_value("audio","music_volume",0))==60,"mute and volume persist")
	scene.set_zoom(2.5);options.load("user://audio.cfg")
	check(float(options.get_value("audio","music_volume",0))==60,"view settings do not overwrite audio settings")
	scene.toggle_music();check(scene.music.playing,"switching music on resumes playback")
	var before: int=audio.index;audio.next_track()
	check(audio.index!=before and scene.music.playing,"next track changes playable song")
	scene.world.enter_map(9);audio.set_map(9)
	check(str(audio.tracks[audio.index]["id"])=="013" and scene.music.stream.loop,"compatible hospital map selects verified original composition")
	var original: Array=audio.tracks.duplicate(true)
	audio.tracks=[{"id":"bad","path":"art/missing-audio.oggdata","name":"Missing"},original[0]];audio.index=0
	check(audio.play_selected() and audio.index==1,"missing track falls back to valid bundled audio")
	audio.tracks=original;audio.index=0;audio.play_selected()
	scene.game_ui.show_audio();await process_frame
	check(scene.game_ui.page=="audio" and not scene.joystick.is_processing_input(),"large audio controls open with gameplay input suspended")
	await process_frame;await process_frame
	check(root.get_visible_rect().encloses(scene.game_ui.panel.get_global_rect()),"audio controls fit within the readable viewport")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v08-audio.png")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	print("MUSIC PLAYBACK: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
