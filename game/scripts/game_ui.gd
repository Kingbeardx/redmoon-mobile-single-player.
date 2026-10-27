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
var shop_hero_only: bool=true
var shop_selection: String=""
var shop_buttons: Dictionary={}
var shop_buy_button: Button
var selected_skill: int=0
var skill_buttons: Dictionary={}
var skill_assign_buttons: Array=[]
var skill_cast_button: Button
var effect_text: Label
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
	button("BAG",show_bag,tabs);button("CHARACTER"+(" +%d" % scene.world.bonus_points if scene.world.bonus_points>0 else ""),show_stats,tabs);button("SKILLS",show_skills,tabs);button("JOURNEY",show_journal,tabs)

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

	for field in ["attack","defense","hp","mp","strength","spirit","dexterity","power"]:
		if int(item.get(field,0))!=0: label("%s  +%d" % [field.to_upper(),int(item[field])],parent)
	label("Required level: %d" % int(item.get("required_level",0)),parent,24)
	if key.get_slice(":",0) in ["1","2","3"]:
		label("For: "+scene.world.allowed_heroes(key),parent,24)
		label(scene.world.equipment_reason(key),parent,26)
	for field in ATTRIBUTES:
		if int(item.get("required_"+field,0))>0: label("Requires %d %s" % [int(item["required_"+field]),field.capitalize()],parent,24)
	var description: String=str(item.get("description",""))
	if not description.is_empty():label(description.replace("\\\\n","\n").replace("\\n","\n").replace("\t"," "),parent,24)

func show_stats() -> void:
	draft={"strength":0,"spirit":0,"dexterity":0,"power":0}
	render_stats()

func render_stats() -> void:
	open_page("%s · %s · LV %d · XP %d/%d" % [scene.world.player_name,scene.world.HERO_NAMES[scene.world.character_id],scene.world.level,scene.world.xp,scene.world.level*40],"stats")
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
	label("HONOR %+d / ±%d · Creature labels show the change for defeating them." % [scene.world.honor,scene.world.honor_cap()],content,24)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	button("SAVE GAME",func():scene._save();show_journal(),list)
	button("MINIMAP: "+("ON" if scene.minimap_visible else "OFF"),func():scene.minimap_visible=not scene.minimap_visible;scene.queue_redraw();show_journal(),list)
	button("TOWN GUIDE / TRAVEL",func():close();scene.inventory_panel.show();scene._travel_rows(),list)
	button("TALK TO NEARBY NPC",talk_nearby,list)
	button("CHARACTER SKILLS & HOTBAR",show_skills,list)
	button("USE NEARBY EXIT",func():close();scene.world.use_exit();scene.textures.clear();scene._sync_map_selection(),list)
	button("CLAIM BOUNTY · 10 DEFEATS",func():scene.world.claim_bounty();show_journal(),list)
	button("MUSIC & SOUND",show_audio,list)
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
	if name=="Doctor":greeting="I can restore your health and mana. "+scene.world.doctor_guidance()
	elif name=="BankClerk":greeting="Your savings are safe here. Bank balance: %d gold." % scene.world.bank_gold
	dialogue_text=label(response if not response.is_empty() else greeting,words,30)
	dialogue_primary=null
	if name=="Doctor":
		dialogue_primary=button("BEGIN TRAINING" if scene.world.adventure_started and scene.world.tutorial_stage==0 else ("COMPLETE TRAINING" if scene.world.adventure_started and scene.world.tutorial_stage==3 else "RESTORE HEALTH & MANA"),func():
			scene.world.interact_with(speaker);open_dialogue(speaker,scene.world.message),content)
	elif name=="BankClerk":
		button("DEPOSIT GOLD",func():scene.world.deposit_gold();open_dialogue(speaker),content)
		button("WITHDRAW GOLD",func():scene.world.withdraw_gold();open_dialogue(speaker),content)
	else:
		var is_shop: bool=scene.world.npc_has_shop(npc)
		if is_shop:
			dialogue_primary=button("BROWSE SHOP",func():
				if scene.world.interact_with(speaker):close();scene.inventory_panel.show();scene._market_rows(),content)
	button("WHAT SHOULD I DO NEXT?",func():open_dialogue(speaker,scene.world.dialogue_guidance(speaker)),content)
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


func show_audio() -> void:
	open_page("MUSIC & SOUND","audio")
	var audio=scene.audio_controller
	label("%s · %d / %d" % [audio.title(),audio.index+1,audio.tracks.size()],content,32)
	button("MUSIC: "+("ON" if scene.music_enabled else "OFF"),func():scene.toggle_music();show_audio(),content)
	var volume_label:=label("MUSIC VOLUME: %d%%" % int(audio.volume),content,30)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);content.add_child(row)
	button("−",func():audio.set_volume(audio.volume-10);show_audio(),row).custom_minimum_size.x=90
	var slider:=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=5;slider.value=audio.volume
	slider.custom_minimum_size=Vector2(600,64);slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(slider)
	slider.value_changed.connect(func(value: float):audio.set_volume(value);volume_label.text="MUSIC VOLUME: %d%%" % int(value))
	button("+",func():audio.set_volume(audio.volume+10);show_audio(),row).custom_minimum_size.x=90
	var navigation:=HBoxContainer.new();navigation.add_theme_constant_override("separation",16);content.add_child(navigation)
	button("PREVIOUS TRACK",func():audio.next_track(-1);show_audio(),navigation)
	button("NEXT TRACK",func():audio.next_track(1);show_audio(),navigation)
	button("SOUND EFFECTS: "+("ON" if scene.sounds_enabled else "OFF"),func():scene.sounds_enabled=not scene.sounds_enabled;audio.save_settings();show_audio(),content)
	if audio.enabled and not audio.player.playing:label(audio.status,content,24)


func show_shop() -> void:
	open_page("MARKET · %s · %d GOLD" % [scene.world.HERO_NAMES[scene.world.character_id],scene.world.gold],"shop")
	shop_buttons.clear();shop_buy_button=null
	var filters:=HBoxContainer.new();content.add_child(filters)
	button("FOR MY HERO",func():shop_hero_only=true;show_shop(),filters).disabled=shop_hero_only
	button("ALL STOCK",func():shop_hero_only=false;show_shop(),filters).disabled=not shop_hero_only
	var hint: String="Uses magic or psychic abilities; physical weapons cannot be equipped." if scene.world.character_id in [0,1] else "Check class, level and attribute requirements before buying."
	label(hint,content,24)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",18);content.add_child(body)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=680;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	var list:=VBoxContainer.new();list.custom_minimum_size.x=648;scroll.add_child(list)
	var selected: Dictionary={}
	for item in scene.world.zone_stock():
		var reason: String=scene.world.equipment_reason(item["key"])
		if shop_hero_only and reason.begins_with("Not for"):continue
		var purchase: String=item["purchase_key"]
		if shop_selection.is_empty():shop_selection=purchase
		var entry:=button("%s · %d gold
%s" % [item["name"],item["price"],reason],func():shop_selection=purchase;show_shop(),list)
		entry.custom_minimum_size.y=88;entry.add_theme_font_size_override("font_size",25);scene._set_item_icon(entry,item["key"]);shop_buttons[purchase]=entry
		if shop_selection==purchase:selected=item
	if selected.is_empty() and not shop_buttons.is_empty():
		shop_selection=str(shop_buttons.keys()[0]);show_shop();return
	var details_scroll:=ScrollContainer.new();details_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(details_scroll)
	var details:=VBoxContainer.new();details.custom_minimum_size.x=384;details.add_theme_constant_override("separation",12);details_scroll.add_child(details)
	if selected.is_empty():
		label("NO COMPATIBLE STOCK",details,30)
		label("Philar and Azlar use psychic or magical abilities and cannot equip physical weapons. Try clothing, accessories and your Strike skill." if scene.world.character_id in [0,1] else "This shop has no compatible items. Choose ALL STOCK to inspect its other equipment.",details,26)
	else:
		var key: String=selected["key"];var reason: String=scene.world.equipment_reason(key)
		label(scene.world.item_name(key),details,32)
		label(reason,details,28).add_theme_color_override("font_color",Color("80d5ad") if reason in ["Equip now","Usable item"] else Color("edb77c"))
		var price: int=selected["price"];var purchase: String=selected["purchase_key"]
		shop_buy_button=button(("BUY FOR LATER · %d GOLD" if reason.begins_with("Requires") else "BUY · %d GOLD") % price,func():scene.world.buy_stock(purchase);selected_item=key;show_shop(),details)
		shop_buy_button.disabled=reason.begins_with("Not for") or scene.world.gold<price
		if key.get_slice(":",0) in ["1","2","3"]:label("For: "+scene.world.allowed_heroes(key),details,24)
		label(scene.world.item_details(key),details,24)
		if scene.world.gold<price:label("You need %d more gold." % (price-scene.world.gold),details,24)
	label(scene.world.message,content,24).max_lines_visible=2

func skill_texture(id: int) -> Texture2D:
	if scene.skill_textures.has(id):return scene.skill_textures[id]
	var sprite: String=scene.art.get("skill_icons",{}).get(str(id),"")
	var box: Array=scene.art.get("images",{}).get(sprite,[])
	if box.size()<4:return load("res://ui/strike.svg")
	var image:=Image.new();var payload: String=str(box[4]) if box.size()>4 else sprite
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art/"+payload+".pngdata"))!=OK:return null
	var texture: Texture2D=ImageTexture.create_from_image(image);scene.skill_textures[id]=texture;return texture

func show_skills() -> void:
	var system=scene.world.skills;system.ensure_slots()
	open_page("%s · SKILLS · LEVEL %d" % [scene.world.HERO_NAMES[scene.world.character_id].to_upper(),scene.world.level],"skills")
	button("ACTIVE EFFECTS & PROTECTION",show_effects,content)
	skill_buttons.clear();skill_assign_buttons.clear()
	var row: Dictionary=system.entry(selected_skill)
	if row.is_empty() or (selected_skill!=-1 and int(row.get("hero",-1))!=scene.world.character_id):
		selected_skill=int(system.slots[0]);row=system.entry(selected_skill)
	if row.is_empty():selected_skill=-1;row=system.entry(-1)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",24);content.add_child(body)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=390;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8);scroll.add_child(list)
	var rows: Array=system.for_hero();rows.push_front(system.entry(-1))
	for item in rows:
		var id: int=int(item["id"]);var ready: bool=system.requirement(id)=="Ready"
		var title: String=str(item["name"])+"\nLv %d · %s" % [int(item["level"]),"READY" if ready else "LOCKED"]
		var option:=button(title,func():selected_skill=id;show_skills(),list)
		option.icon=skill_texture(id);option.expand_icon=true;option.add_theme_constant_override("icon_max_width",54);option.add_theme_font_size_override("font_size",23);option.custom_minimum_size.y=82
		option.modulate=Color.WHITE if ready else Color("a7a4ae")
		if id==selected_skill:option.add_theme_stylebox_override("normal",scene._style(Color("3b3440"),Color("f0ca7a")))
		skill_buttons[id]=option
	var detail_scroll:=ScrollContainer.new();detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(detail_scroll)
	var details:=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",12);detail_scroll.add_child(details)
	var heading:=HBoxContainer.new();heading.add_theme_constant_override("separation",14);details.add_child(heading)
	var icon:=TextureRect.new();icon.texture=skill_texture(selected_skill);icon.custom_minimum_size=Vector2(90,64);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;heading.add_child(icon)
	label(str(row["name"]),heading,32).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var reason: String=system.requirement(selected_skill)
	label(reason.to_upper(),details,28)
	skill_cast_button=button("CAST NOW",func():close();scene._cast_skill_id(selected_skill),details)
	skill_cast_button.disabled=reason!="Ready" or scene.world.mana<system.cost(selected_skill)
	var binds:=HBoxContainer.new();binds.add_theme_constant_override("separation",8);details.add_child(binds)
	for slot in range(3):
		var index: int=slot
		var bind:=button("SLOT %d" % (slot+1),func():
			if system.assign(index,selected_skill):scene._save();show_skills(),binds)
		bind.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bind.disabled=reason!="Ready";skill_assign_buttons.append(bind)
	label(str(row["description"]),details,26)
	var encoded: int=int(row["mana_encoded"])
	var mana_text: String="%d MP" % encoded if encoded<1000000000 else "%d%% of maximum MP" % mini(100,encoded-1000000000)
	if selected_skill in [1,2]:mana_text="1 MP per 2 HP restored"
	label("Level %d  ·  %s\nRange %s tiles  ·  %s" % [int(row["level"]),mana_text,str(row["range"]),"AREA" if bool(row["area"]) else "SINGLE / SELF"],details,25)
	var honor: int=int(row["honor"])
	if honor!=0:label("Honor required: %+d · Your honor: %+d\nDefeat creatures marked with the honor change you want.
Current cap: ±100. Higher caps need quests not yet restored." % [honor,scene.world.honor],details,25)
	if row["mode"]=="pending":label("This original skill is recorded here, but its effects are not playable yet."+(" It needs the special DP system." if int(row["kind"])==1 else ""),details,25)
	else:label("Original requirements and icons. Combat effects are reconstructed for offline play."+(" Nearby-ally healing applies to you in single-player." if row["mode"]=="heal" and selected_skill!=1 else ""),details,23)
	label("YOUR HOTBAR",details,25)
	for slot in range(3):
		var equipped: Dictionary=system.entry(int(system.slots[slot]))
		button("%d · %s  × CLEAR" % [slot+1,equipped.get("name","Empty")],func():system.assign(slot,0);scene._save();show_skills(),details)

func show_effects() -> void:
	open_page("ACTIVE EFFECTS","effects")
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(scroll)
	var body:=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",20);scroll.add_child(body)
	effect_text=label("",body,30);refresh_effects()
	label("Root stops movement. Freeze and sleep stop movement, attacks and most skills. Cleansing abilities and consumables remain usable. Damage wakes you from sleep. Blindness blocks basic attacks; slowing reduces movement speed.",body,26)
	label("Cleansing skills remove harmful effects. Mental protection prevents new ones while it lasts. Control effects last up to 3 seconds, followed by a brief resistance window in this offline adventure.",body,26)
	button("BACK TO SKILLS",show_skills,body)

func refresh_effects() -> void:
	if page!="effects" or not is_instance_valid(effect_text):return
	var lines: PackedStringArray=[]
	for name in scene.world.skills.ailments:lines.append("%s · %ds" % [str(name).to_upper(),int(ceil(scene.world.skills.ailments[name]))])
	for buff in scene.world.skills.buffs.values():lines.append("%s · %ds%s" % [buff["name"],int(ceil(buff["remaining"]))," · %d protected hits" % int(buff["charges"]) if buff.has("charges") else ""])
	effect_text.text="No active effects." if lines.is_empty() else "\n\n".join(lines)
