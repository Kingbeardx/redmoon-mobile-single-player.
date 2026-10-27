extends RefCounted
## Mobile title/creation flow. The existing save is untouched until confirmation.
var scene: Node
var panel: PanelContainer
var column: VBoxContainer
var name_input: LineEdit
var hero_select: OptionButton
var preview: TextureRect
var feedback: Label
var replace_dialog: ConfirmationDialog
var has_save: bool=false

func setup(owner_scene: Node, existing: bool) -> void:
	scene=owner_scene;has_save=existing
	panel=PanelContainer.new()
	panel.z_index=100
	panel.add_theme_stylebox_override("panel",scene._style(Color(0.035,0.05,0.075,1),scene.TEAL))
	scene.root_ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new();panel.add_child(center)
	column=VBoxContainer.new();column.custom_minimum_size=Vector2(680,0);column.add_theme_constant_override("separation",10);center.add_child(column)
	replace_dialog=ConfirmationDialog.new();replace_dialog.title="Replace saved character?"
	replace_dialog.dialog_text="This replaces the current adventure on this device."
	replace_dialog.confirmed.connect(_create)
	panel.add_child(replace_dialog)
	show_title()

func clear() -> void:
	for child in column.get_children(): column.remove_child(child);child.queue_free()

func label(text: String, size: int=19) -> Label:
	var item:=Label.new();item.text=text;item.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size",size);column.add_child(item);return item

func button(text: String, action: Callable) -> Button:
	var item: Button=scene._button(text,scene.INK)
	scene.root_ui.remove_child(item);column.add_child(item)
	item.custom_minimum_size.y=48;item.pressed.connect(action);return item

func show_title() -> void:
	clear();panel.show();scene.inventory_panel.hide()
	scene.joystick.direction=Vector2.ZERO;scene.joystick.active_touch=-1;scene.joystick.set_process_input(false)
	label("REDMOON",38)
	label("Offline Adventure",22)
	label("Create a hero, meet the Doctor and explore Street 1.")
	var continue_button:=button("CONTINUE · %s · %s" % [scene.world.player_name,scene.world.map_name()],close_for_play)
	continue_button.disabled=not has_save
	button("NEW CHARACTER",show_creation)
	label("One character per device save · progress saves automatically",15)

func close_for_play() -> void:
	panel.hide();scene.joystick.set_process_input(true)
	scene._sync_map_selection();scene._update_ui()

func show_creation() -> void:
	clear()
	label("CREATE YOUR CHARACTER",29)
	name_input=LineEdit.new();name_input.placeholder_text="Character name (2–14 characters)";name_input.max_length=14
	name_input.custom_minimum_size.y=48;name_input.add_theme_font_size_override("font_size",22);column.add_child(name_input)
	hero_select=OptionButton.new();hero_select.custom_minimum_size.y=48;hero_select.add_theme_font_size_override("font_size",22)
	for hero in scene.world.HERO_NAMES: hero_select.add_item(hero)
	hero_select.item_selected.connect(_preview);column.add_child(hero_select)
	preview=TextureRect.new();preview.custom_minimum_size=Vector2(140,130);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;column.add_child(preview)
	label("Level 1 · Strength 10 · Spirit 10 · Dexterity 10 · Power 10",17)
	label("Begin safely at Street 1 Hospital. Speak with the Doctor for supplies.",17)
	feedback=label("",16)
	button("BEGIN ADVENTURE",_begin)
	button("BACK",show_title)
	_preview(0)

func _preview(hero: int) -> void:
	preview.texture=null
	var frames: Array=scene.art.get("actor_states",{}).get(str(hero),{}).get("idle",{}).get("2",[])
	if frames.is_empty(): return
	var key: String=frames[0];var box: Array=scene.art.get("images",{}).get(key,[])
	if box.size()<5: return
	var image:=Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art/"+str(box[4])+".pngdata"))==OK:
		preview.texture=ImageTexture.create_from_image(image)

func _begin() -> void:
	if name_input.text.strip_edges().length()<2:
		feedback.text="Please enter a name of 2–14 characters.";return
	if has_save: replace_dialog.popup_centered()
	else: _create()

func _create() -> void:
	if scene.world.create_character(name_input.text,hero_select.selected):
		has_save=true;scene.textures.clear();close_for_play()
	else: feedback.text="Could not create the character. Check device storage and name."
