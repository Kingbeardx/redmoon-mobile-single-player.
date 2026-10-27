extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func click(control: Control) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=control.get_global_rect().get_center()
		root.push_input(event,true)
	await process_frame
func find_key(node: Node,text: String) -> Button:
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var result:=find_key(child,text)
		if result!=null:return result
	return null
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.frontend.show_creation();await process_frame
	check(scene.frontend.hero_buttons.size()==9,"nine portrait selection buttons")
	check(scene.frontend.preview.size.y>=290,"large hero showcase")
	check(not scene.frontend.name_input.text.is_empty(),"default name avoids empty-name blocker")
	await click(scene.frontend.hero_buttons[2])
	check(scene.frontend.selected_hero==2 and scene.frontend.hero_heading.text=="SADAD","real GUI click selects hero")
	await click(find_key(scene.frontend.panel,"EDIT NAME"));await process_frame
	check(scene.frontend.keyboard_panel.visible,"GUI edit button opens in-game keyboard")
	check(not scene.frontend.keyboard_input.virtual_keyboard_enabled,"name entry does not depend on native keyboard")
	await click(find_key(scene.frontend.keyboard_panel,"CLEAR"))
	for ch in "MOBILE":await click(find_key(scene.frontend.keyboard_panel,ch))
	check(scene.frontend.keyboard_input.text=="MOBILE","GUI keyboard keys enter chosen name")
	var digit:=find_key(scene.frontend.keyboard_panel,"1")
	for pressed in [true,false]:
		var touch:=InputEventScreenTouch.new();touch.index=0;touch.pressed=pressed;touch.position=digit.get_global_rect().get_center()
		Input.parse_input_event(touch);await process_frame
	check(scene.frontend.keyboard_input.text=="MOBILE1","touch events enter name through mouse emulation")
	await click(find_key(scene.frontend.keyboard_panel,"DELETE"))
	await click(find_key(scene.frontend.keyboard_panel,"DELETE"))
	check(scene.frontend.keyboard_input.text=="MOBIL","GUI backspace edits name")
	await click(find_key(scene.frontend.keyboard_panel,"DONE"))
	check(scene.frontend.name_input.text=="MOBIL" and not scene.frontend.keyboard_panel.visible,"DONE commits typed name")
	await click(find_key(scene.frontend.panel,"BEGIN ADVENTURE"))
	check(not scene.frontend.panel.visible and scene.world.player_name=="MOBIL" and scene.world.character_id==2,"create named hero through actual GUI input")
	check(scene.world_zoom==2.0,"closer world view is default")
	check(scene.stats.get_theme_font_size("font_size")>=28 and scene.status.get_theme_font_size("font_size")>=24,"large high-contrast HUD text")
	scene.set_zoom(2.5)
	var config:=ConfigFile.new();config.load("user://accessibility.cfg")
	check(config.get_value("view","zoom")==2.5,"zoom preference persists")
	scene.set_zoom(99);check(scene.world_zoom==3.0,"maximum zoom bound")
	scene.set_zoom(0);check(scene.world_zoom==1.25,"minimum zoom bound")
	scene.set_zoom(2)
	scene._show_inventory();await process_frame
	check(scene.game_ui.panel.size.x>=1000 and scene.game_ui.item_buttons.size()>0,"large inventory controls")
	check(scene.frontend.name_input.editable,"name field remains editable with hardware keyboard")
	if DisplayServer.get_name()!="headless":
		scene.game_ui.close();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/redmoon-mobile/analysis/v06-close-view.png")
	print("ACCESSIBILITY: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
