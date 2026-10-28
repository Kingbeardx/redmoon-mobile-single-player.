extends RefCounted
## Accessible character showcase and a touch keyboard independent of the OS IME.
var scene: Node
var panel: PanelContainer
var column: VBoxContainer
var name_input: LineEdit
var hero_buttons: Array[Button]=[]
var selected_hero: int=0
var preview: TextureRect
var hero_heading: Label
var profiles: Dictionary={}
var bio_panel: PanelContainer
var bio_body: VBoxContainer
var feedback: Label
var replace_dialog: ConfirmationDialog
var has_save: bool=false
var keyboard_panel: PanelContainer
var keyboard_input: LineEdit
var keyboard_feedback: Label

func setup(owner_scene: Node, existing: bool) -> void:
	scene=owner_scene;has_save=existing
	var data=scene.world.read_json("res://data/hero-profiles.json")
	if data is Dictionary:profiles=data.get("profiles",{})
	panel=PanelContainer.new();panel.z_index=100
	panel.add_theme_stylebox_override("panel",scene._style(Color("0b0b10"),Color("b69862")))
	scene.root_ui.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new();panel.add_child(center)
	column=VBoxContainer.new();column.custom_minimum_size=Vector2(1120,0);column.add_theme_constant_override("separation",10);center.add_child(column)
	replace_dialog=ConfirmationDialog.new();replace_dialog.title="Replace saved character?"
	replace_dialog.dialog_text="This replaces the current adventure on this device."
	replace_dialog.confirmed.connect(_create);panel.add_child(replace_dialog)
	_build_keyboard();_build_bio();show_title()

func clear() -> void:
	hero_buttons.clear()
	for child in column.get_children(): column.remove_child(child);child.queue_free()

func label(text: String, size: int=28, parent: Node=null) -> Label:
	var item:=Label.new();item.text=text;item.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size",size);item.add_theme_color_override("font_color",Color("f5eddb"))
	(parent if parent!=null else column).add_child(item);return item

func button(text: String, action: Callable, parent: Node=null) -> Button:
	var item: Button=scene._button(text,Color("231b1b"),Color("9e8155"))
	scene.root_ui.remove_child(item);(parent if parent!=null else column).add_child(item)
	item.custom_minimum_size.y=60;item.pressed.connect(action);return item

func show_title() -> void:
	clear();keyboard_panel.hide();bio_panel.hide();panel.show();scene.inventory_panel.hide();scene.game_ui.close()
	scene.joystick.direction=Vector2.ZERO;scene.joystick.active_touch=-1;scene.joystick.mouse_dragging=false;scene.joystick.set_process_input(false)
	label("REDMOON",52);label("OFFLINE ADVENTURE",32)
	label("Create your hero. Explore Street 1 and the world beyond.")
	var resume:=button("CONTINUE · %s · %s" % [scene.world.player_name,scene.world.map_name()],close_for_play)
	resume.disabled=not has_save
	button("NEW CHARACTER",show_creation)
	button("MUSIC: "+("ON" if scene.music_enabled else "OFF"),func():scene.toggle_music();show_title())
	label("One saved character · progress saves automatically",26)

func close_for_play() -> void:
	keyboard_panel.hide();bio_panel.hide();panel.hide();scene.joystick.set_process_input(true)
	scene._sync_map_selection();scene._update_ui()

func show_creation() -> void:
	clear();keyboard_panel.hide();selected_hero=0
	label("CHOOSE YOUR HERO",40)
	var stage:=HBoxContainer.new();stage.add_theme_constant_override("separation",24);column.add_child(stage)
	var portrait:=VBoxContainer.new();portrait.custom_minimum_size=Vector2(360,0);stage.add_child(portrait)
	hero_heading=label("PHILAR",32,portrait)
	preview=TextureRect.new();preview.custom_minimum_size=Vector2(360,300);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.add_child(preview)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);stage.add_child(grid)
	for hero in range(scene.world.HERO_NAMES.size()):
		var id: int=hero
		var card:=button("",func():select_hero(id),grid);card.custom_minimum_size=Vector2(232,108)
		var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.offset_left=12;row.offset_right=-8
		var icon:=TextureRect.new();icon.custom_minimum_size=Vector2(58,100);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.texture=_hero_texture(hero);icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;row.add_child(icon)
		var caption:=label(scene.world.HERO_NAMES[hero],25,row);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hero_buttons.append(card)
	var name_row:=HBoxContainer.new();name_row.add_theme_constant_override("separation",12);column.add_child(name_row)
	label("NAME",28,name_row)
	name_input=LineEdit.new();name_input.text=scene.world.HERO_NAMES[0];name_input.max_length=14;name_input.editable=true
	name_input.placeholder_text="Tap EDIT NAME";name_input.virtual_keyboard_enabled=false;name_input.focus_mode=Control.FOCUS_ALL
	name_input.custom_minimum_size=Vector2(530,60);name_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name_input.add_theme_font_size_override("font_size",32);name_row.add_child(name_input)
	name_input.gui_input.connect(func(event: InputEvent):
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed: open_keyboard.call_deferred())
	button("EDIT NAME",open_keyboard,name_row)
	feedback=label("Level 1 · Begin at Street 1 Hospital. The Doctor will guide you.",26)
	button("STORY, SKILLS & EQUIPMENT",show_bio)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",16);column.add_child(actions)
	button("BACK",show_title,actions).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("BEGIN ADVENTURE",_begin,actions).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	select_hero(0)

func _hero_texture(hero: int) -> Texture2D:
	var frames: Array=scene.art.get("actor_states",{}).get(str(scene.world.server_hero(hero)),{}).get("idle",{}).get("2",[])
	if frames.is_empty(): return null
	var box: Array=scene.art.get("images",{}).get(str(frames[0]),[])
	if box.size()<5: return null
	var image:=Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art/"+str(box[4])+".pngdata"))!=OK: return null
	var bounds:=image.get_used_rect()
	if bounds.has_area(): image=image.get_region(bounds)
	return ImageTexture.create_from_image(image)

func select_hero(hero: int) -> void:
	var old: String=scene.world.HERO_NAMES[selected_hero]
	selected_hero=clampi(hero,0,8);preview.texture=_hero_texture(selected_hero)
	hero_heading.text=scene.world.HERO_NAMES[selected_hero].to_upper()
	var info: Dictionary=profiles.get(str(selected_hero),{})
	feedback.text="Weapons: "+str(info.get("weapon_hint","See item requirements"))+" · Story & equipment below"
	if name_input.text==old or name_input.text.strip_edges().is_empty(): name_input.text=scene.world.HERO_NAMES[selected_hero]
	for id in range(hero_buttons.size()):
		hero_buttons[id].add_theme_stylebox_override("normal",scene._style(Color("543426") if id==selected_hero else Color("1a171b"),Color("ffcf76") if id==selected_hero else Color("746047")))

func _begin() -> void:
	if name_input.text.strip_edges().is_empty(): name_input.text=scene.world.HERO_NAMES[selected_hero]
	if name_input.text.strip_edges().length()<2:
		feedback.text="Use EDIT NAME to enter 2–14 characters.";open_keyboard();return
	if has_save: replace_dialog.popup_centered()
	else: _create()

func _create() -> void:
	if scene.coop.active():scene.coop.stop()
	if scene.world.create_character(name_input.text,selected_hero):
		scene.world.campaign.restore({});scene.world.party.allies.clear();scene.world.party.portal.clear();scene.world.set_combat_mode(true);scene.world.save_game()
		has_save=true;scene.textures.clear();close_for_play()
	else: feedback.text="Could not create the character. Check storage and name."

func _build_keyboard() -> void:
	keyboard_panel=PanelContainer.new();keyboard_panel.z_index=200
	keyboard_panel.add_theme_stylebox_override("panel",scene._style(Color("111018"),Color("e3bd7b")))
	scene.root_ui.add_child(keyboard_panel);keyboard_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new();keyboard_panel.add_child(center)
	var body:=VBoxContainer.new();body.custom_minimum_size=Vector2(1100,0);body.add_theme_constant_override("separation",10);center.add_child(body)
	label("ENTER YOUR CHARACTER NAME",36,body)
	keyboard_input=LineEdit.new();keyboard_input.max_length=14;keyboard_input.virtual_keyboard_enabled=false
	keyboard_input.custom_minimum_size.y=64;keyboard_input.add_theme_font_size_override("font_size",36);body.add_child(keyboard_input)
	for keys in ["1234567890","QWERTYUIOP","ASDFGHJKL","ZXCVBNM"]:
		var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",8);body.add_child(row)
		for ch in keys:
			var character: String=ch
			var key:=button(ch,func():keyboard_key(character),row);key.custom_minimum_size=Vector2(96,62);key.add_theme_font_size_override("font_size",32)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",10);body.add_child(actions)
	button("CLEAR",func():keyboard_input.text="",actions)
	button("SPACE",func():keyboard_key(" "),actions)
	button("DELETE",keyboard_delete,actions)
	button("CANCEL",func():keyboard_panel.hide(),actions)
	button("DONE",finish_keyboard,actions).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	keyboard_feedback=label("Touch the keys above, then DONE. Maximum 14 characters.",26,body)
	keyboard_panel.hide()

func open_keyboard() -> void:
	keyboard_input.text=name_input.text;keyboard_input.caret_column=keyboard_input.text.length()
	keyboard_feedback.text="Touch the keys above, then DONE. Maximum 14 characters."
	keyboard_panel.show()
	keyboard_input.grab_focus()

func keyboard_key(character: String) -> void:
	if keyboard_input.text.length()>=14: return
	var caret: int=keyboard_input.caret_column
	keyboard_input.text=keyboard_input.text.left(caret)+character+keyboard_input.text.substr(caret)
	keyboard_input.caret_column=caret+1

func keyboard_delete() -> void:
	var caret: int=keyboard_input.caret_column
	if caret<=0: return
	keyboard_input.text=keyboard_input.text.left(caret-1)+keyboard_input.text.substr(caret)
	keyboard_input.caret_column=caret-1

func finish_keyboard() -> void:
	if keyboard_input.text.strip_edges().length()<2:
		keyboard_feedback.text="Please enter at least 2 characters.";return
	name_input.text=keyboard_input.text.strip_edges();keyboard_panel.hide()


func _build_bio() -> void:
	bio_panel=PanelContainer.new();bio_panel.z_index=150;bio_panel.add_theme_stylebox_override("panel",scene._style(Color("101722"),Color("a48c69")))
	scene.root_ui.add_child(bio_panel);bio_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new();bio_panel.add_child(center)
	bio_body=VBoxContainer.new();bio_body.custom_minimum_size=Vector2(1120,600);bio_body.add_theme_constant_override("separation",14);center.add_child(bio_body);bio_panel.hide()

func show_bio() -> void:
	for node in bio_body.get_children():bio_body.remove_child(node);node.queue_free()
	var info: Dictionary=profiles.get(str(selected_hero),{})
	label(scene.world.HERO_NAMES[selected_hero].to_upper()+" · CHARACTER PROFILE",34,bio_body)
	var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",22);bio_body.add_child(row)
	var image:=TextureRect.new();image.texture=_hero_texture(selected_hero);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(220,420);row.add_child(image)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(860,420);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_child(scroll)
	var words:=VBoxContainer.new();words.custom_minimum_size.x=820;words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",14);scroll.add_child(words)
	var story:=label(str(info.get("story","Biography unavailable.")),26,words);story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;story.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	var gear:=label("WEAPONS: "+str(info.get("weapon_hint","See item requirements")),28,words);gear.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	var examples: Array=info.get("weapon_examples",[])
	var text: String="Uses psychic or magical abilities, not physical weapons." if examples.is_empty() else "Compatible examples: "+", ".join(PackedStringArray(examples))
	var detail:=label(text,26,words);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	var summary: PackedStringArray=[]
	for skill in scene.world.skills.for_hero(selected_hero):
		if int(skill["kind"])==0 and int(skill["honor"])==0:
			summary.append("Lv %d · %s%s" % [int(skill["level"]),skill["name"]," (not playable yet)" if skill["mode"]=="pending" else ""])
	var skills:=label("CHARACTER SKILLS\n"+"\n".join(summary)+"\nSkills unlock at their original levels. Open BAG → SKILLS to inspect the full list and assign three touch slots. Advanced and honor skills are still being reconstructed.",26,words);skills.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;skills.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	button("BACK TO CHARACTER SELECTION",func():bio_panel.hide(),bio_body)
	bio_panel.show()
