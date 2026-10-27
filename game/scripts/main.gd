extends Node2D

const WorldScript = preload("res://scripts/world.gd")
const JoystickScript = preload("res://scripts/joystick.gd")
const TILE: Vector2 = Vector2(48.0, 24.0)
const INK := Color(0.06, 0.08, 0.11)
const MUTED := Color(0.56, 0.63, 0.71)
const WHITE := Color(0.9, 0.93, 0.96)
const RED := Color(0.84, 0.23, 0.29)
const TEAL := Color(0.24, 0.79, 0.71)

var art: Dictionary = {}
var client_maps: Dictionary = {}
var textures: Dictionary = {}
var object_draws: Array = []
var image_last_used: Dictionary = {}
var draw_epoch: int = 0
var sounds_enabled: bool = true
var audio_players: Dictionary = {}
var music: AudioStreamPlayer
var music_enabled: bool = true
var audio_controller=preload("res://scripts/music_controller.gd").new()
var inventory_panel: PanelContainer
var inventory_list: VBoxContainer

var game_ui=preload("res://scripts/game_ui.gd").new()
var pending_npc: Dictionary={}
var npc_path: Array[Vector2i]=[]
var npc_repath: float=0.0
var frontend = preload("res://scripts/frontend.gd").new()
var world = WorldScript.new()
var joystick: Control
var root_ui: Control
var status: Label
var stats: Label
var location_label: Label
var help_label: Label
var hp_text: Label
var mp_text: Label
var xp_bar: ProgressBar
var mp_bar: ProgressBar
var skill_button: Button
var extra_skill_buttons: Array=[]
var skill_textures: Dictionary={}
var buff_label: Label
var food_button: Button
var minimap_visible: bool=false
var status_age: float=0
var last_status: String=""
var paused_at: float=0
var hp_bar: ProgressBar
var map_select: OptionButton
var attack_button: Button
var heal_button: Button
var save_button: Button
var reset_dialog: ConfirmationDialog
var autosave_elapsed: float = 0.0
var ready_world: bool = false
var ui_elapsed: float = 0.0
var show_overlay: bool = false
var camera_origin := Vector2.ZERO
var world_zoom: float=2.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.027, 0.039, 0.059))
	var options:=ConfigFile.new()
	if options.load("user://accessibility.cfg")==OK:
		world_zoom=clampf(float(options.get_value("view","zoom",2.0)),1.25,3.0)
	_build_ui()
	ready_world = world.initialize()
	var loaded_art = world.read_json("res://data/client-art.json")
	if loaded_art is Dictionary:
		art = loaded_art
	var loaded_maps = world.read_json("res://data/client-maps.json")
	if loaded_maps is Dictionary:
		client_maps = loaded_maps
	_build_inventory()
	game_ui.setup(self)
	if ready_world:
		var existing: bool=world.load_game()
		_sync_map_selection()
		frontend.setup(self,existing)
	else:
		status.text = world.load_error
		attack_button.disabled = true
		heal_button.disabled = true
		map_select.disabled = true
	get_viewport().size_changed.connect(_layout)
	_layout()
	add_child(audio_controller)
	audio_controller.setup(self)
	if is_instance_valid(frontend.panel) and frontend.panel.visible:frontend.show_title()
	_update_ui()

func _style(background: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(text_value: String, font_size: int, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", maxi(24,int(font_size*1.25)))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(label)
	return label

func _button(text_value: String, fill: Color, border: Color = Color(0.25, 0.32, 0.4)) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", _style(fill, border))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.1), border.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.15), border.lightened(0.15)))
	button.add_theme_stylebox_override("disabled", _style(fill.darkened(0.4), border.darkened(0.3)))
	button.focus_mode = Control.FOCUS_NONE
	root_ui.add_child(button)
	return button

func _build_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	root_ui=Control.new();root_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);root_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root_ui)
	var health:=Panel.new();health.name="HealthCard";health.add_theme_stylebox_override("panel",_style(Color(0.025,.035,.05,.88),Color("776550"),14));health.mouse_filter=Control.MOUSE_FILTER_IGNORE;root_ui.add_child(health)
	health.mouse_filter=Control.MOUSE_FILTER_STOP
	health.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:game_ui.show_stats())
	var portrait:=TextureRect.new();portrait.name="Portrait";portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;root_ui.add_child(portrait)
	stats=_label("",24);stats.name="HeroName";stats.add_theme_font_size_override("font_size",28)
	hp_bar=ProgressBar.new();mp_bar=ProgressBar.new()
	for bar in [hp_bar,mp_bar]:
		bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_theme_stylebox_override("background",_style(Color("171921"),Color("342e2d"),8));root_ui.add_child(bar)
	xp_bar=ProgressBar.new();xp_bar.show_percentage=false;xp_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;xp_bar.add_theme_stylebox_override("background",_style(Color("171921"),Color("171921"),2));xp_bar.add_theme_stylebox_override("fill",_style(Color("d6b567"),Color("d6b567"),2));root_ui.add_child(xp_bar)
	for state in ["background","fill"]:
		var skin=xp_bar.get_theme_stylebox(state).duplicate();skin.content_margin_top=0;skin.content_margin_bottom=0;skin.content_margin_left=0;skin.content_margin_right=0;skin.set_border_width_all(0);xp_bar.add_theme_stylebox_override(state,skin)
	hp_bar.add_theme_stylebox_override("fill",_style(Color("b92c45"),Color("ee7582"),8));mp_bar.add_theme_stylebox_override("fill",_style(Color("197b9f"),Color("73d4e1"),8))
	hp_text=_label("",24);mp_text=_label("",24)
	for label in [hp_text,mp_text]:label.add_theme_font_size_override("font_size",26);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	location_label=_label("",24);location_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	help_label=_label("",24);help_label.add_theme_stylebox_override("normal",_style(Color(0.025,.035,.05,.82),Color("776550"),12));help_label.clip_text=true
	status=_label("",24);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.max_lines_visible=2;status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;status.add_theme_stylebox_override("normal",_style(Color(0.025,.035,.05,.9),Color("776550"),12))
	joystick=JoystickScript.new();root_ui.add_child(joystick)
	attack_button=_action("ATTACK","attack",Color("dc526b"));heal_button=_action("HEAL","heal",Color("4dc9ac"));skill_button=_action("STRIKE","strike",Color("75b3f4"));food_button=_action("FOOD","food",Color("d8b66d"))
	attack_button.pressed.connect(func():
		if not OS.has_feature("mobile"):_attack())
	heal_button.pressed.connect(func():
		if not OS.has_feature("mobile"):_heal())
	skill_button.pressed.connect(func():
		if not OS.has_feature("mobile"):_skill())
	food_button.pressed.connect(func():
		if not OS.has_feature("mobile"):_food())
	for slot in range(1,3):
		var index: int=slot
		var extra: Button=_action("SKILL","strike",Color("75b3f4"));extra_skill_buttons.append(extra)
		extra.pressed.connect(func():
			if not OS.has_feature("mobile"):_skill(index))
		extra.caption.add_theme_font_size_override("font_size",19)
		extra.caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;extra.caption.size.y=44
	skill_button.caption.add_theme_font_size_override("font_size",19);skill_button.caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;skill_button.caption.size.y=44
	buff_label=_label("",23);buff_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	skill_button.tooltip_text="Character skill";heal_button.tooltip_text="Healing charge";food_button.tooltip_text="Use food or a drink from your bag"
	map_select=OptionButton.new();map_select.add_theme_font_size_override("font_size",24);map_select.add_theme_stylebox_override("normal",_style(INK,Color("776550")));map_select.focus_mode=Control.FOCUS_NONE;map_select.item_selected.connect(_change_map);root_ui.add_child(map_select)
	var menu:=_button("MENU",INK,Color("776550"));menu.name="Menu";menu.pressed.connect(func():_save();frontend.has_save=true;frontend.show_title())
	save_button=_button("SAVE",INK);save_button.hide();save_button.pressed.connect(_save)
	reset_dialog=ConfirmationDialog.new();root_ui.add_child(reset_dialog)
	var closer:=_button("+",INK);closer.name="ZoomIn";closer.pressed.connect(func():set_zoom(world_zoom+.25))
	var farther:=_button("−",INK);farther.name="ZoomOut";farther.pressed.connect(func():set_zoom(world_zoom-.25))

func _action(title: String,icon: String,color: Color) -> Button:
	var action=preload("res://scripts/action_button.gd").new();root_ui.add_child(action);action.setup(title,load("res://ui/"+icon+".svg"),color);return action

func _layout() -> void:
	var view: Vector2=get_viewport_rect().size;root_ui.size=view
	root_ui.get_node("HealthCard").position=Vector2(20,18);root_ui.get_node("HealthCard").size=Vector2(370,126)
	root_ui.get_node("Portrait").position=Vector2(28,26);root_ui.get_node("Portrait").size=Vector2(66,104)
	stats.position=Vector2(106,20);stats.size=Vector2(276,35)
	xp_bar.position=Vector2(106,135);xp_bar.size=Vector2(270,4)
	hp_bar.position=Vector2(106,58);hp_bar.size=Vector2(270,32);hp_text.position=hp_bar.position;hp_text.size=hp_bar.size
	mp_bar.position=Vector2(106,100);mp_bar.size=Vector2(270,26);mp_text.position=mp_bar.position;mp_text.size=mp_bar.size
	location_label.position=Vector2(408,22);location_label.size=Vector2(maxf(180,view.x-884),42);location_label.clip_text=true
	map_select.position=Vector2(view.x-450,20);map_select.size=Vector2(164,60)
	root_ui.get_node("Menu").position=Vector2(view.x-150,20);root_ui.get_node("Menu").size=Vector2(130,60)
	root_ui.get_node("ZoomIn").position=Vector2(view.x-86,100);root_ui.get_node("ZoomIn").size=Vector2(64,60)
	root_ui.get_node("ZoomOut").position=Vector2(view.x-86,170);root_ui.get_node("ZoomOut").size=Vector2(64,60)
	joystick.position=Vector2(20,view.y-188);joystick.size=Vector2(164,164)
	attack_button.position=Vector2(view.x-140,view.y-144);attack_button.size=Vector2(116,116)
	skill_button.position=Vector2(view.x-254,view.y-128);skill_button.size=Vector2(100,100)
	heal_button.position=Vector2(view.x-368,view.y-128);heal_button.size=Vector2(100,100)
	food_button.position=Vector2(view.x-482,view.y-128);food_button.size=Vector2(100,100)
	for index in range(extra_skill_buttons.size()):
		extra_skill_buttons[index].position=Vector2(view.x-254-index*114,view.y-242);extra_skill_buttons[index].size=Vector2(100,100)
	buff_label.position=Vector2(20,210);buff_label.size=Vector2(370,100)
	help_label.position=Vector2(20,152);help_label.size=Vector2(370,48)
	status.position=Vector2(view.x*.5-240,view.y-224);status.size=Vector2(480,66)
	if inventory_panel!=null:inventory_panel.position=Vector2(40,90);inventory_panel.size=Vector2(view.x-80,view.y-114)
	if root_ui.has_node("BagButton"):root_ui.get_node("BagButton").position=Vector2(view.x-272,20);root_ui.get_node("BagButton").size=Vector2(108,60)
	if game_ui.panel!=null:game_ui.layout()
	queue_redraw()

func _process(delta: float) -> void:
	if not ready_world:
		return
	if audio_controller.player!=null:audio_controller.set_map(world.map_id)
	if ui_blocked():
		world.advance_respawns(delta)
		world.skills.tick(delta)
		return
	status_age+=delta
	status.modulate.a=1.0 if status_age<5 else maxf(0,1-(status_age-5))
	var direction: Vector2 = joystick.direction
	if not get_viewport().gui_get_focus_owner():
		direction += Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction.length_squared()>0.01:
		pending_npc.clear();npc_path.clear()
	elif not pending_npc.is_empty():
		direction=approach_npc(delta)
		if game_ui.panel.visible: return
	# Invert isometric projection so controls always follow screen directions.
	var map_direction := direction.limit_length(1.0)
	world.tick(delta, map_direction)
	autosave_elapsed += delta
	ui_elapsed += delta
	if autosave_elapsed >= 20.0:
		autosave_elapsed = 0.0
		world.save_game()
	if ui_elapsed >= 0.08:
		ui_elapsed = 0.0
		_update_ui()
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Buttons rely on mouse emulation, which follows only one finger. Handle
	# combat touches directly so a second finger works while the joystick is held.
	if not ready_world or ui_blocked():
		return
	if event is InputEventScreenTouch and event.pressed:
		for index in range(extra_skill_buttons.size()):
			if extra_skill_buttons[index].get_global_rect().has_point(event.position):
				_skill(index+1);get_viewport().set_input_as_handled();return
		if attack_button.get_global_rect().has_point(event.position):
			_attack()
			get_viewport().set_input_as_handled()
		elif heal_button.get_global_rect().has_point(event.position):
			_heal()
			get_viewport().set_input_as_handled()
		elif skill_button.get_global_rect().has_point(event.position):
			_skill();get_viewport().set_input_as_handled()
		elif food_button.get_global_rect().has_point(event.position):
			_food();get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if ui_blocked() or not ready_world or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_SPACE:
		_attack()
	elif event.physical_keycode == KEY_E:
		_heal()
	elif event.physical_keycode == KEY_Q:_skill()
	elif event.physical_keycode == KEY_1:_skill()
	elif event.physical_keycode == KEY_2:_skill(1)
	elif event.physical_keycode == KEY_3:_skill(2)
	elif event.physical_keycode == KEY_K:game_ui.show_skills()
	elif event.physical_keycode == KEY_R:_food()
	elif event.physical_keycode == KEY_F5:
		_save()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED] and is_instance_valid(audio_controller) and is_instance_valid(audio_controller.player):
		audio_controller.player.stream_paused=what==NOTIFICATION_APPLICATION_PAUSED
	if what==NOTIFICATION_APPLICATION_PAUSED:paused_at=Time.get_unix_time_from_system()
	elif what==NOTIFICATION_APPLICATION_RESUMED and paused_at>0:
		var away: float=maxf(0,Time.get_unix_time_from_system()-paused_at)
		world.advance_respawns(away);world.skills.tick(away);paused_at=0
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST,NOTIFICATION_APPLICATION_FOCUS_OUT] and ready_world and is_instance_valid(frontend.panel) and not frontend.panel.visible:
		world.save_game()

func _change_map(index: int) -> void:
	if world.travel_to(map_select.get_item_id(index)):
		textures.clear()
		world.save_game()
		_sync_map_selection()
		_update_ui()
	else:
		world.message = "This recovered map could not be loaded."
		_sync_map_selection()

func _sync_map_selection() -> void:
	map_select.clear()
	map_select.add_item("TRAVEL · "+world.map_name(),world.map_id)
	for id in world.travel_options():
		if id!=world.map_id: map_select.add_item(world.map_name(id),id)
	map_select.select(0)
	map_select.text="TRAVEL"

func _attack() -> void:
	var prior: int = world.defeated
	if world.attack():
		play_sound("loot" if world.defeated>prior else "attack")
	_update_ui()

func _heal() -> void:
	if world.heal():
		play_sound("heal")
	_update_ui()

func _save() -> void:
	if world.save_game() != OK:
		world.message = "Could not save progress on this device."
	else:
		world.message = "Progress saved on this device."
	_update_ui()

func _update_ui() -> void:
	if not ready_world:return
	if audio_controller.player!=null:audio_controller.set_map(world.map_id)
	if map_select.item_count==0 or map_select.get_item_id(map_select.selected)!=world.map_id:_sync_map_selection()
	stats.text="%s · Lv %d" % [world.HERO_NAMES[world.character_id],world.level]
	stats.tooltip_text="XP %d / %d · Gold %d · Stat points %d" % [world.xp,world.level*40,world.gold,world.bonus_points]
	xp_bar.max_value=world.level*40;xp_bar.value=world.xp
	hp_bar.max_value=world.max_hp();hp_bar.value=world.hp;mp_bar.max_value=world.max_mana();mp_bar.value=world.mana
	hp_text.text="HP %d / %d" % [world.hp,world.max_hp()];mp_text.text="MP %d / %d" % [world.mana,world.max_mana()]
	location_label.text=world.map_name()
	if status.text!=world.message:status_age=0;status.modulate.a=1
	status.text=world.message
	help_label.text=["Meet the Doctor","Visit Street 1","Backyard · %d / 3" % world.tutorial_kills,"Return to Doctor","Explore Redmoon"][world.tutorial_stage] if world.adventure_started else "Explore Redmoon"
	var cooldown: float=world.attack_cooldown/.45
	attack_button.set_state("",cooldown)
	heal_button.disabled=world.potions<=0;heal_button.set_state(str(world.potions),0)
	world.skills.ensure_slots()
	var actions: Array=[skill_button]+extra_skill_buttons
	for index in range(3):
		var id: int=int(world.skills.slots[index]);var row: Dictionary=world.skills.entry(id);var button: Button=actions[index]
		button.caption.text=str(row.get("name","SKILLS")).to_upper()
		button.picture.texture=game_ui.skill_texture(id)
		button.tooltip_text=str(row.get("name","Choose a skill"))+" · Open BAG → SKILLS to assign"
		button.disabled=id!=0 and (world.skills.requirement(id)!="Ready" or world.mana<world.skills.cost(id))
		button.set_state(str(world.skills.cost(id)) if id!=0 else "+",maxf(cooldown,float(world.skills.cooldowns.get(id,0))/world.skills.RECOVERY))
	var active: PackedStringArray=[]
	for buff in world.skills.buffs.values():active.append("%s · %ds" % [buff["name"],int(ceil(buff["remaining"]))])
	buff_label.text="\n".join(active)
	var food: int=0
	for key in world.inventory:
		if str(key).begins_with("4:"):food+=int(world.inventory[key])
	food_button.disabled=food<=0;food_button.set_state(str(food),0)
	var portrait: TextureRect=root_ui.get_node("Portrait")
	if int(portrait.get_meta("hero",-1))!=world.character_id:
		portrait.texture=frontend._hero_texture(world.character_id);attack_button.picture.texture=load("res://ui/strike.svg") if world.character_id in [0,1] else load("res://ui/attack.svg");portrait.set_meta("hero",world.character_id)

func _skill(slot: int=0) -> void:
	world.skills.ensure_slots()
	if int(world.skills.slots[slot])==0:game_ui.show_skills();return
	_cast_skill_id(int(world.skills.slots[slot]))

func _cast_skill_id(id: int) -> void:
	if world.skills.cast(id):play_sound("heal" if world.skills.entry(id).get("mode")=="heal" else "attack")
	_update_ui()

func _food() -> void:
	if world.quick_food():play_sound("heal")
	_update_ui()

func gameplay_rect() -> Rect2:return get_viewport_rect()

func iso(point: Vector2) -> Vector2:
	return point * TILE

func _draw() -> void:
	if not ready_world:
		return
	draw_epoch+=1
	if textures.size()>1024:
		for cached in textures.keys():
			if int(image_last_used.get(cached,0))<draw_epoch-1:
				textures.erase(cached)
				image_last_used.erase(cached)
	object_draws.clear()
	var screen: Vector2=get_viewport_rect().size
	var viewport: Vector2=screen/world_zoom
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*world_zoom)
	camera_origin = Vector2(viewport.x * 0.5, viewport.y * 0.62) - iso(world.player)
	var center := Vector2i(world.player)
	var x_span: int = int(ceil(viewport.x / TILE.x)) + 10
	var y_span: int = int(ceil(viewport.y / TILE.y)) + 5
	var span: int = maxi(x_span, y_span)
	for y in range(maxi(0, center.y - span), mini(world.height, center.y + span + 1)):
		for x in range(maxi(0, center.x - span), mini(world.width, center.x + span + 1)):
			var point: Vector2 = iso(Vector2(x + 0.5, y + 0.5)) + camera_origin
			if point.x < -TILE.x or point.x > viewport.x + TILE.x or point.y < -120 or point.y > viewport.y+120:
				continue
			if _draw_original_tile(x, y, point):
				continue
			var open: bool = world.is_open(Vector2i(x, y))
			var shade: float = float((x * 17 + y * 13) % 7) * 0.004
			var fill: Color = Color(0.10 + shade, 0.15 + shade, 0.19 + shade) if open else Color(0.043, 0.063, 0.085)
			var polygon := PackedVector2Array([point + Vector2(0, -12), point + Vector2(24, 0), point + Vector2(0, 12), point + Vector2(-24, 0)])
			draw_colored_polygon(polygon, fill)
			if open:
				draw_line(polygon[0], polygon[1], Color(0.18, 0.23, 0.28, 0.5), 1.0)
				draw_line(polygon[1], polygon[2], Color(0.18, 0.23, 0.28, 0.4), 1.0)
			elif (x + y) % 4 == 0:
				draw_circle(point, 1.3, Color(0.13, 0.17, 0.21))
	var entities: Array = object_draws.duplicate()
	for enemy in world.enemies:
		if bool(enemy.get("alive", false)):
			entities.append({"position": Vector2(float(enemy["x"]), float(enemy["y"])), "enemy": enemy, "player": false})
	for npc in world.content.get("npcs", []):
		if int(npc.get("map_id", -1)) == world.map_id:
			var b: Dictionary = npc["bounds"]
			entities.append({"position": Vector2((float(b["left"])+float(b["right"]))*0.5, (float(b["top"])+float(b["bottom"]))*0.5), "player": false, "enemy": {"npc":true,"npc_name":str(npc["name"]).trim_prefix("+"),"monster_id":0,"appearance":int(npc["image_id"])}})
	for exit in world.map_exit_rectangles():
		entities.append({"position":Vector2((float(exit["left"])+float(exit["right"]))/96.0,(float(exit["top"])+float(exit["bottom"]))/48.0),"player":false,"exit":true})
	entities.append({"position": world.player, "player": true})
	entities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["position"].y < b["position"].y)
	for entry in entities:
		var point: Vector2 = iso(entry["position"]) + camera_origin
		if point.x < -40 or point.x > viewport.x + 40 or point.y < -120 or point.y > viewport.y+120:
			continue
		if entry.has("exit"):
			draw_circle(point,8,TEAL)
			draw_string(ThemeDB.fallback_font,point+Vector2(-16,-15),"EXIT",HORIZONTAL_ALIGNMENT_LEFT,-1,13,TEAL)
		elif entry.has("object"):
			_draw_image(str(entry["object"]),point-TILE*0.5)
		else:
			_draw_actor(point, bool(entry["player"]), entry.get("enemy", {}))
	if world.attack_flash > 0.0:
		var point: Vector2 = iso(world.player) + camera_origin
		var alpha: float = world.attack_flash / 0.18
		draw_arc(point + Vector2(0, -8), 35 + (1.0 - alpha) * 22, -PI * 0.9, PI * 0.15, 24, Color(1.0, 0.74, 0.5, alpha), 4, true)

	for effect in world.skills.effects:
		var pos: Vector2=iso(Vector2(effect["x"],effect["y"]))+camera_origin
		var frames: Array=art.get("skill_projectiles",{}).get(str(effect.get("skill_id",0)),{}).get(str(effect.get("facing",6)),[])
		if not frames.is_empty():
			var progress: float=clampf(1-float(effect["remaining"])/.65,0,1)
			var start: Vector2=iso(Vector2(effect["start_x"],effect["start_y"]))+camera_origin
			var projectile: Vector2=start.lerp(pos,progress)+Vector2(0,-30)
			_draw_image(str(frames[mini(frames.size()-1,int(progress*frames.size()))]),projectile)
		var tint:=Color("7ee8c1") if effect["mode"]=="heal" else Color("87cefa")
		tint.a=clampf(float(effect["remaining"])/.65,0,1)
		draw_arc(pos+Vector2(0,-10),18+(1-tint.a)*26,0,TAU,32,tint,2,true)
		draw_string(ThemeDB.fallback_font,pos+Vector2(-22,-65-(1-tint.a)*20),str(effect["label"]),HORIZONTAL_ALIGNMENT_LEFT,-1,18,tint)
	draw_set_transform(Vector2.ZERO)
	_draw_minimap(screen)

func _draw_actor(point: Vector2, is_player: bool, enemy: Dictionary) -> void:
	if enemy.get("npc", false):
		draw_string(ThemeDB.fallback_font, point + Vector2(-35,-65), str(enemy.get("npc_name","NPC")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.GOLD)
	if not is_player and not enemy.get("npc",false):
		var change: int=world.expected_honor(int(enemy.get("monster_id",0)))
		if change!=0:draw_string(ThemeDB.fallback_font,point+Vector2(-34,-78),"Honor %+d" % change,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8ed8f0") if change>0 else Color("f0a590"))
		var state_text: String=""
		for ailment in ["sleep","freeze","blind","root","slow","stun"]:
			if float(enemy.get(ailment+"_time",0))>0:state_text=ailment.to_upper();break
		if not state_text.is_empty():draw_string(ThemeDB.fallback_font,point+Vector2(-20,-94),state_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ddc2f2"))
	var appearance: int = world.character_id if is_player else int(enemy.get("appearance",world.appearance(int(enemy.get("monster_id", 0)))))
	var sequences: Array = art.get("actors", {}).get(str(appearance), [])
	if not sequences.is_empty():
		var frames: Array = sequences[0]
		var moving: bool = world.motion.length_squared()>0.01 if is_player else bool(enemy.get("moving",false))
		var state: String = ("run" if world.running else "walk") if moving and is_player else ("walk" if moving else "idle")
		var facing: int = world.facing if is_player else int(enemy.get("facing",6))
		var action_frames: Array = art.get("actor_states",{}).get(str(appearance),{}).get(state,{}).get(str(facing),[])
		if not action_frames.is_empty():
			frames = action_frames
		var frame: int = int(world.elapsed / 0.06) % frames.size()
		var key: String = frames[frame]
		_draw_image(key, point)
		if not is_player and not enemy.get("npc",false):
			draw_rect(Rect2(point + Vector2(-18, -60), Vector2(36.0 * float(enemy.get("hp",36)) / 36.0, 3)), RED)
		return
	draw_set_transform(point*world_zoom, 0.0, Vector2(world_zoom, 0.43*world_zoom))
	draw_circle(Vector2.ZERO, 17, Color(0.0, 0.0, 0.0, 0.5))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*world_zoom)
	if is_player:
		draw_arc(point, 19, 0, TAU, 32, Color(0.31, 0.86, 0.8, 0.85), 1.5, true)
		var body := PackedVector2Array([point + Vector2(0, -33), point + Vector2(11, -15), point + Vector2(7, -2), point + Vector2(-8, -2), point + Vector2(-11, -15)])
		draw_colored_polygon(body, Color(0.19, 0.63, 0.65))
		draw_line(point + Vector2(-5, -18), point + Vector2(8, -15), Color(0.6, 0.92, 0.88), 3)
		draw_circle(point + Vector2(0, -35), 7, Color(0.9, 0.85, 0.74))
		draw_line(point + Vector2(9, -15), point + Vector2(20, -30), Color(0.85, 0.91, 0.95), 3, true)
		draw_string(ThemeDB.fallback_font, point + Vector2(-12, -54), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEAL)
	else:
		var tint: Color = Color.from_hsv(0.96 + float(int(enemy.get("monster_id", 0)) % 5) * 0.015, 0.58, 0.71)
		var body := PackedVector2Array([point + Vector2(0, -29), point + Vector2(12, -19), point + Vector2(9, -3), point + Vector2(-9, -3), point + Vector2(-12, -19)])
		draw_colored_polygon(body, tint)
		draw_circle(point + Vector2(-4, -21), 1.7, Color(1.0, 0.82, 0.58))
		draw_circle(point + Vector2(4, -21), 1.7, Color(1.0, 0.82, 0.58))
		draw_rect(Rect2(point + Vector2(-17, -39), Vector2(34, 4)), Color(0.12, 0.08, 0.11))
		draw_rect(Rect2(point + Vector2(-17, -39), Vector2(34.0 * float(enemy.get("hp", 36)) / 36.0, 4)), RED)
		draw_string(ThemeDB.fallback_font, point + Vector2(-18, -45), "#%d" % int(enemy.get("monster_id", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.62, 0.65))

func _draw_minimap(viewport: Vector2) -> void:
	if not minimap_visible:return
	var panel := Rect2(Vector2(viewport.x - 272, 96), Vector2(156, 166))
	draw_style_box(_style(Color(0.035, 0.05, 0.075, 0.94), Color(0.18, 0.26, 0.33), 10), panel)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(13, 22), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, MUTED)
	var scale_factor: float = minf(126.0 / float(world.width), 126.0 / float(world.height))
	var origin: Vector2 = panel.position + Vector2(15, 32)
	var step: int = maxi(1, int(ceil(maxi(world.width, world.height) / 70.0)))
	for y in range(0, world.height, step):
		for x in range(0, world.width, step):
			if world.is_open(Vector2i(x, y)):
				draw_rect(Rect2(origin + Vector2(x, y) * scale_factor, Vector2.ONE * maxf(1, step * scale_factor)), Color(0.2, 0.3, 0.35))
	draw_circle(origin + world.player * scale_factor, 3.1, TEAL)

func _draw_image(key: String, point: Vector2) -> bool:
	if not art.get("images", {}).has(key):
		return false
	var box: Array = art["images"][key]
	var payload: String = str(box[4]) if box.size()>4 else key
	if not textures.has(payload):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art/" + payload + ".pngdata")) != OK:
			return false
		textures[payload] = ImageTexture.create_from_image(image)
	image_last_used[payload]=draw_epoch
	draw_texture(textures[payload], point + Vector2(box[0], box[1]))
	return true

func _draw_original_tile(x: int, y: int, point: Vector2) -> bool:
	var map: Dictionary = client_maps.get(str(world.map_id), {})
	if map.is_empty() or int(map["width"]) != world.width or int(map["height"]) != world.height:
		return false
	var cell: Array = map["cells"][y * world.width + x]
	_draw_image("tle_%d_%d" % [cell[0], cell[1]], point - TILE * 0.5)
	var object_key: String = "obj_%d_%d" % [cell[2],cell[3]]
	var frames: Array = art.get("object_animations",{}).get(object_key,[])
	if not frames.is_empty():
		object_key=frames[int(world.elapsed*8)%frames.size()]
	if art.get("images",{}).has(object_key):
		object_draws.append({"position":Vector2(x+0.5,y+0.5),"player":false,"object":object_key})
	return true

func _build_inventory() -> void:
	var open := _button("BAG", INK,Color("776550"))
	open.name="BagButton"
	open.position = Vector2(400, 12)
	open.size = Vector2(280, 60)
	open.pressed.connect(_show_inventory)
	inventory_panel = PanelContainer.new()
	inventory_panel.position = Vector2(220, 115)
	inventory_panel.size = Vector2(840, 480)
	inventory_panel.add_theme_stylebox_override("panel", _style(INK, TEAL))
	root_ui.add_child(inventory_panel)
	var scroll := ScrollContainer.new()
	inventory_panel.add_child(scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.custom_minimum_size = Vector2(780, 0)
	scroll.add_child(inventory_list)
	inventory_panel.hide()

func _row(text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size",26)
	button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(action)
	inventory_list.add_child(button)
	return button

func _show_inventory() -> void:
	game_ui.show_bag()

func _shop_rows() -> void:
	if not world.shop_available:
		_row(world.message, func(): pass)
		return
	_row("Buy healing charge · 15 gold", func(): world.buy_heal(); _show_inventory())
	for key in world.inventory:
		var item_key: String = str(key)
		_row("Sell %s · %d gold" % [world.item_name(item_key),maxi(0,int(world.item_metadata.get(item_key,{}).get("price",10))/2)], func(): world.sell_item(item_key); _show_inventory())

func play_sound(action: String) -> void:
	if not sounds_enabled:
		return
	if not audio_players.has(action):
		var path: String = "res://art/"+action+".wavdata"
		if not FileAccess.file_exists(path):
			return
		var stream := AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(path))
		if stream == null:
			return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -10
		player.max_polyphony = 4
		add_child(player)
		audio_players[action] = player
	audio_players[action].play()

func _market_rows() -> void:
	game_ui.show_shop()

func toggle_music() -> void:
	audio_controller.toggle()

func _set_item_icon(button: Button,key: String) -> void:
	var sprite: String=art.get("item_icons",{}).get(key,"")
	if sprite.is_empty():
		return
	var box: Array=art["images"][sprite]
	var payload: String=str(box[4]) if box.size()>4 else sprite
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art/"+payload+".pngdata"))==OK:
		button.icon=ImageTexture.create_from_image(image)
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",40)


func _travel_rows() -> void:
	game_ui.close();inventory_panel.show()
	for child in inventory_list.get_children():
		inventory_list.remove_child(child);child.queue_free()
	_row("BACK · "+world.map_name(),_show_inventory)
	_paragraph(world.objective())
	_row("Town guide offers transport between beginner locations.",func():pass)
	for id in world.travel_options():
		if id==world.map_id: continue
		var destination: int=id
		_row("Travel to "+world.map_name(id),func():
			if world.travel_to(destination):
				textures.clear();_sync_map_selection();inventory_panel.hide();_update_ui())


func _talk_rows() -> void:
	game_ui.talk_nearby()

func _paragraph(text: String) -> void:
	var label:=Label.new()
	label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size=Vector2(760,80)
	label.add_theme_font_size_override("font_size",26)
	inventory_list.add_child(label)


func set_zoom(value: float) -> void:
	world_zoom=clampf(value,1.25,3.0)
	var options:=ConfigFile.new();options.set_value("view","zoom",world_zoom);options.save("user://accessibility.cfg")
	queue_redraw()


func ui_blocked() -> bool:
	return reset_dialog.visible or inventory_panel.visible or (game_ui.panel!=null and game_ui.panel.visible) or (frontend.panel!=null and frontend.panel.visible)

func npc_screen_rect(npc: Dictionary) -> Rect2:
	var point: Vector2=(iso(world.npc_position(npc))+camera_origin)*world_zoom
	return Rect2(point+Vector2(-35,-85)*world_zoom,Vector2(70,90)*world_zoom).grow(12)

func npc_at_screen(position: Vector2) -> Dictionary:
	var area:=gameplay_rect()
	if not area.has_point(position):return {}
	var result: Dictionary={}
	var best: float=INF
	for npc in world.content.get("npcs",[]):
		if int(npc.get("map_id",-1))!=world.map_id:continue
		var rect:=npc_screen_rect(npc)
		if rect.has_point(position):
			var distance: float=rect.get_center().distance_squared_to(position)
			if distance<=best:result=npc;best=distance
	return result

func _unhandled_input(event: InputEvent) -> void:
	if not ready_world or ui_blocked():return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT):
		for action in [attack_button,heal_button,skill_button,food_button]+extra_skill_buttons:
			if action.get_global_rect().has_point(event.position):return
		var npc:=npc_at_screen(event.position)
		if npc.is_empty():return
		if world.npc_position(npc).distance_to(world.player)<8:game_ui.open_dialogue(npc)
		else:
			pending_npc=npc.duplicate(true);npc_path.clear();npc_repath=0
			world.message="Walking to "+str(npc.get("name","NPC")).trim_prefix("+")+". Move the pad to cancel."
		get_viewport().set_input_as_handled()

func approach_npc(delta: float) -> Vector2:
	if int(pending_npc.get("map_id",-1))!=world.map_id:
		pending_npc.clear();return Vector2.ZERO
	if world.npc_position(pending_npc).distance_to(world.player)<7.5:
		var target:=pending_npc.duplicate(true);pending_npc.clear();npc_path.clear();game_ui.open_dialogue(target);return Vector2.ZERO
	npc_repath-=delta
	if npc_repath<=0 or npc_path.is_empty():
		npc_repath=0.6
		var target: Vector2=world.find_start([int(world.npc_position(pending_npc).x),int(world.npc_position(pending_npc).y)])
		npc_path=world.navigation.get_id_path(Vector2i(world.player.floor()),Vector2i(target.floor()))
		if not npc_path.is_empty():npc_path.pop_front()
		if npc_path.is_empty():
			pending_npc.clear();world.message="No clear route to this person. Try moving closer.";return Vector2.ZERO
	while not npc_path.is_empty() and world.player.distance_to(Vector2(npc_path[0])+Vector2(0.5,0.5))<0.2:npc_path.pop_front()
	if npc_path.is_empty():return Vector2.ZERO
	return world.player.direction_to(Vector2(npc_path[0])+Vector2(0.5,0.5))
