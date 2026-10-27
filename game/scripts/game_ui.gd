extends RefCounted
## Inventory, staged attributes and contextual NPC conversations share one modal.
var scene: Node
var panel: PanelContainer
var content: VBoxContainer
var selected_item: String=""
var item_filter: String="All"
var item_buttons: Dictionary={}
var item_action: Button
var stat_plus: Dictionary={}
var stat_minus: Dictionary={}
var draft: Dictionary={}
var apply_button: Button
var speaker: Dictionary={}
var dialogue_text: Label
var dialogue_primary: Button
var page: String=""
const ATTRIBUTES=["strength","spirit","dexterity","power"]
const DESCRIPTIONS={"strength":"Equipment requirements", "spirit":"Maximum mana and equipment", "dexterity":"Equipment requirements", "power":"Maximum health and equipment"}

func setup(owner_scene: Node) -> void:
	scene=owner_scene
	panel=PanelContainer.new();panel.z_index=40
	panel.add_theme_stylebox_override("panel",scene._style(Color("101117"),Color("c2a166")))
	scene.root_ui.add_child(panel)
	content=VBoxContainer.new();content.add_theme_constant_override("separation",12);panel.add_child(content)
	panel.hide();layout()

func layout() -> void:
	var size: Vector2=scene.get_viewport_rect().size
	panel.position=Vector2(32,24);panel.size=Vector2(size.x-64,size.y-48)

func close() -> void:
	panel.hide();draft.clear();scene.joystick.direction=Vector2.ZERO;scene.joystick.active_touch=-1;scene.joystick.mouse_dragging=false
	scene.joystick.set_process_input(scene.frontend.panel==null or not scene.frontend.panel.visible)
	scene._update_ui()

func label(text: String,parent: Node,size: int=26) -> Label:
	var item:=Label.new();item.text=text;item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("f4ecd9"));item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item);return item

func button(text: String,action: Callable,parent: Node) -> Button:
	var item: Button=scene._button(text,Color("25212a"),Color("aa8b56"))
	scene.root_ui.remove_child(item);parent.add_child(item);item.custom_minimum_size.y=60
	item.pressed.connect(action);return item

func open_page(title: String,kind: String) -> void:
	page=kind;scene.pending_npc.clear();scene.npc_path.clear();scene.inventory_panel.hide();scene.joystick.direction=Vector2.ZERO;scene.joystick.active_touch=-1;scene.joystick.mouse_dragging=false;scene.joystick.set_process_input(false)
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	panel.show();layout()
	var header:=HBoxContainer.new();content.add_child(header)
	label(title,header,34).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("CLOSE",close,header)
	var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",10);content.add_child(tabs)
	button("BAG",show_bag,tabs);button("CHARACTER"+(" +%d" % scene.world.bonus_points if scene.world.bonus_points>0 else ""),show_stats,tabs);button("JOURNEY",show_journal,tabs)

func show_bag() -> void:
	open_page("INVENTORY  ·  %d GOLD" % scene.world.gold,"bag")
	item_buttons.clear()
	var filters:=HBoxContainer.new();content.add_child(filters)
	for category in ["All","Gear","Food","Other"]:
		var chosen: String=category
		button(category,func():item_filter=chosen;show_bag(),filters).disabled=category==item_filter
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",20);content.add_child(body)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=716;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var grid:=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
	var keys: Array=scene.world.inventory.keys();keys.sort()
	for key in keys:
		if int(scene.world.inventory[key])<=0: continue
		var kind: String=str(key).get_slice(":",0)
		if item_filter=="Gear" and kind not in ["1","2","3"]: continue
		if item_filter=="Food" and kind!="4": continue
		if item_filter=="Other" and kind in ["1","2","3","4"]: continue
		var item_key: String=key
		var slot:=button("",func():selected_item=item_key;show_bag(),grid);slot.custom_minimum_size=Vector2(132,124)
		slot.tooltip_text=scene.world.item_name(key)
		var inner:=VBoxContainer.new();inner.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(inner);inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon:=TextureRect.new();icon.texture=item_texture(key);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size=Vector2(120,80);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;inner.add_child(icon)
		var count:=label(("EQUIPPED" if scene.world.equipment.values().has(key) else "× %d" % int(scene.world.inventory[key])),inner,22)
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;count.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if key==selected_item or scene.world.equipment.values().has(key):
			slot.add_theme_stylebox_override("normal",scene._style(Color("4e3827"),Color("f8cd80")))
		item_buttons[key]=slot
	for i in range(maxi(0,15-item_buttons.size())):
		var empty:=Panel.new();empty.custom_minimum_size=Vector2(132,124);empty.add_theme_stylebox_override("panel",scene._style(Color("181921"),Color("42434e")));grid.add_child(empty)
	var detail_scroll:=ScrollContainer.new();detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(detail_scroll)
	var detail:=VBoxContainer.new();detail.custom_minimum_size.x=366;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",10);detail_scroll.add_child(detail)
	item_action=null
	if selected_item.is_empty() or int(scene.world.inventory.get(selected_item,0))<=0:
		label("SELECT AN ITEM",detail,30);label("Tap an icon to see its name, effects and requirements.",detail)
	else: show_item_detail(detail)
	var notice:=label(scene.world.message,content,24);notice.max_lines_visible=2

func item_texture(key: String) -> Texture2D:
	var sprite: String=scene.art.get("item_icons",{}).get(key,"")
	if sprite.is_empty():return null
	var box: Array=scene.art.get("images",{}).get(sprite,[])
	if box.size()<5:return null
	var image:=Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art/"+str(box[4])+".pngdata"))!=OK:return null
	return ImageTexture.create_from_image(image)

func show_item_detail(parent: Node) -> void:
	var key: String=selected_item
	var item: Dictionary=scene.world.item_metadata.get(key,{})
	label(scene.world.item_name(key),parent,32)
	label("Owned: %d" % int(scene.world.inventory[key]),parent)
	for field in ["attack","defense","hp","mp","strength","spirit","dexterity","power"]:
		if int(item.get(field,0))!=0: label("%s  +%d" % [field.to_upper(),int(item[field])],parent)
	label("Required level: %d" % int(item.get("required_level",0)),parent,24)
	for field in ATTRIBUTES:
		if int(item.get("required_"+field,0))>0: label("Requires %d %s" % [int(item["required_"+field]),field.capitalize()],parent,24)
	var description: String=str(item.get("description",""))
	if not description.is_empty():label(description.replace("\\\\n","\n").replace("\\n","\n").replace("\t"," "),parent,24)
	var equipped: bool=scene.world.equipment.values().has(key)
	var kind: String=key.get_slice(":",0)
	var action: String="UNEQUIP" if equipped else ("EQUIP" if kind in ["1","2","3"] else "USE ITEM")
	item_action=button(action,func():
		if equipped:
			for slot in scene.world.equipment.keys():
				if scene.world.equipment[slot]==key:scene.world.equipment.erase(slot)
			scene.world.refresh_equipment();scene.world.save_game();scene.world.message="Unequipped "+scene.world.item_name(key)
		else:scene.world.use_item(key)
		show_bag(),parent)
	item_action.disabled=item.is_empty() or kind not in ["1","2","3","4"]
	if not equipped and not item.is_empty() and kind in ["1","2","3"] and int(item.get("characters",0))!=0 and (int(item.get("characters",0)) & (1<<scene.world.character_id))==0:
		label("Your hero cannot equip this item.",parent,24);item_action.disabled=true
	if scene.world.shop_available:
		button("SELL ONE · %d GOLD" % (int(item.get("price",0))/2),func():scene.world.sell_item(key);show_bag(),parent)

func show_stats() -> void:
	draft={"strength":0,"spirit":0,"dexterity":0,"power":0}
	render_stats()

func render_stats() -> void:
	open_page("%s  ·  LEVEL %d" % [scene.world.player_name,scene.world.level],"stats")
	stat_plus.clear();stat_minus.clear()
	var spent: int=draft_total()
	label("UNSPENT POINTS: %d     ·     PLANNED: %d" % [scene.world.bonus_points-spent,spent],content,30)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(scroll)
	var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
	for attribute in ATTRIBUTES:
		var key: String=attribute
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);rows.add_child(row)
		label(attribute.capitalize(),row,30).custom_minimum_size.x=180
		label("%d → %d" % [scene.world.effective_stat(attribute),scene.world.effective_stat(attribute)+int(draft[attribute])],row,30).custom_minimum_size.x=180
		label(DESCRIPTIONS[attribute],row,24).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var minus:=button("−",func():change_stat(key,-1),row);minus.custom_minimum_size.x=72;minus.disabled=int(draft[attribute])==0;stat_minus[attribute]=minus
		var plus:=button("+",func():change_stat(key,1),row);plus.custom_minimum_size.x=72;plus.disabled=spent>=scene.world.bonus_points;stat_plus[attribute]=plus
	label("HEALTH %d → %d     MANA %d → %d" % [scene.world.max_hp(),scene.world.hp_for(scene.world.effective_stat("power")+int(draft["power"])),scene.world.max_mana(),scene.world.mana_for(scene.world.effective_stat("spirit")+int(draft["spirit"]))],rows,28)
	label("Level up to earn points. HP/mana change at thresholds. Apply to confirm.",rows,24)
	var actions:=HBoxContainer.new();content.add_child(actions)
	apply_button=button("APPLY POINTS",func():
		scene.world.allocate_stats(draft);show_stats(),actions);apply_button.disabled=spent==0
	button("RESET CHANGES",show_stats,actions)
	label(scene.world.message,content,24).max_lines_visible=1

func draft_total() -> int:
	var total: int=0
	for value in draft.values():total+=int(value)
	return total

func change_stat(attribute: String,delta: int) -> void:
	if not draft.has(attribute):return
	if delta>0 and draft_total()>=scene.world.bonus_points:return
	draft[attribute]=maxi(0,int(draft[attribute])+delta);render_stats()

func show_journal() -> void:
	open_page("JOURNEY & OPTIONS","journal")
	label(scene.world.objective(),content,30)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	button("TOWN GUIDE / TRAVEL",func():close();scene.inventory_panel.show();scene._travel_rows(),list)
	button("TALK TO NEARBY NPC",talk_nearby,list)
	button("POWER STRIKE · 20 MANA",func():close();scene.world.cast_skill(),list)
	button("USE NEARBY EXIT",func():close();scene.world.use_exit();scene.textures.clear();scene._sync_map_selection(),list)
	button("CLAIM BOUNTY · 10 DEFEATS",func():scene.world.claim_bounty();show_journal(),list)
	button("MUSIC: "+("ON" if scene.music_enabled else "OFF"),func():scene.toggle_music();show_journal(),list)
	button("SOUND: "+("ON" if scene.sounds_enabled else "OFF"),func():scene.sounds_enabled=not scene.sounds_enabled;show_journal(),list)
	button("RUN: "+("ON" if scene.world.running else "OFF"),func():scene.world.running=not scene.world.running;show_journal(),list)

func talk_nearby() -> void:
	var npc: Dictionary=scene.world.nearest_npc()
	if npc.is_empty():scene.world.message="Move closer to a town NPC, then tap them.";close()
	else:open_dialogue(npc)

func open_dialogue(npc: Dictionary, response: String="") -> void:
	if int(npc.get("map_id",-1))!=scene.world.map_id or scene.world.npc_position(npc).distance_to(scene.world.player)>=8:
		scene.world.message="Move closer to speak with this person.";return
	speaker=npc.duplicate(true)
	var name: String=str(npc.get("name","Traveler")).trim_prefix("+")
	open_page(name.to_upper(),"dialogue")
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",28);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(body)
	var portrait:=TextureRect.new();portrait.custom_minimum_size=Vector2(170,210);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture=actor_texture(int(npc.get("image_id",0)));body.add_child(portrait)
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(words)
	var greeting: String="Welcome to "+scene.world.map_name()+", "+scene.world.player_name+". How can I help?"
	if name=="Doctor":greeting="I can restore your health and mana. "+scene.world.objective()
	elif name=="BankClerk":greeting="Your savings are safe here. Bank balance: %d gold." % scene.world.bank_gold
	dialogue_text=label(response if not response.is_empty() else greeting,words,30)
	dialogue_primary=null
	if name=="Doctor":
		dialogue_primary=button("BEGIN TRAINING" if scene.world.tutorial_stage==0 else ("COMPLETE TRAINING" if scene.world.tutorial_stage==3 else "RESTORE HEALTH & MANA"),func():
			scene.world.interact_with(speaker);open_dialogue(speaker,scene.world.message),content)
	elif name=="BankClerk":
		button("DEPOSIT GOLD",func():scene.world.deposit_gold();open_dialogue(speaker),content)
		button("WITHDRAW GOLD",func():scene.world.withdraw_gold();open_dialogue(speaker),content)
	else:
		var is_shop: bool=scene.world.npc_has_shop(npc)
		if is_shop:
			dialogue_primary=button("BROWSE SHOP",func():
				if scene.world.interact_with(speaker):close();scene.inventory_panel.show();scene._market_rows(),content)
	button("WHAT SHOULD I DO NEXT?",func():open_dialogue(speaker,scene.world.objective()),content)
	button("GOODBYE",close,content)

func actor_texture(appearance: int) -> Texture2D:
	var frames: Array=scene.art.get("actor_states",{}).get(str(appearance),{}).get("idle",{}).get("6",[])
	if frames.is_empty():
		var sequences: Array=scene.art.get("actors",{}).get(str(appearance),[])
		if not sequences.is_empty():frames=sequences[0]
	if frames.is_empty():return null
	var box: Array=scene.art.get("images",{}).get(str(frames[0]),[])
	if box.size()<5:return null
	var image:=Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art/"+str(box[4])+".pngdata"))!=OK:return null
	return ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
