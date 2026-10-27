extends Button
## Circular action art with a readable label, stock badge and cooldown ring.
var picture: TextureRect
var caption: Label
var badge: Label
var cooldown: float=0
var accent: Color=Color("d45161")
func setup(title: String,texture: Texture2D,color: Color) -> void:
	accent=color;focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("121821") if state!="pressed" else color.darkened(.65)
		style.border_color=color.darkened(.55) if state=="disabled" else color;style.set_border_width_all(2);style.set_corner_radius_all(64)
		style.shadow_color=Color(0,0,0,.7);style.shadow_size=7
		add_theme_stylebox_override(state,style)
	picture=TextureRect.new();picture.texture=texture;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(picture)
	caption=Label.new();caption.text=title;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",24);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(caption)
	badge=Label.new();badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.add_theme_font_size_override("font_size",20);badge.add_theme_color_override("font_color",Color("f8d68e"));badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(badge)
	resized.connect(layout);layout()
func layout() -> void:
	if picture==null:return
	picture.position=Vector2(size.x*.27,14);picture.size=Vector2(size.x*.46,size.y*.46)
	caption.position=Vector2(0,size.y*.65);caption.size=Vector2(size.x,30)
	badge.position=Vector2(size.x*.58,2);badge.size=Vector2(size.x*.4,28)
func set_state(label_text: String,remaining: float) -> void:
	badge.text=label_text;cooldown=clampf(remaining,0,1);picture.modulate=Color(1,1,1,.35) if disabled else Color.WHITE;queue_redraw()
func _draw() -> void:
	if cooldown>0:draw_arc(size*.5,minf(size.x,size.y)*.46,-PI*.5,-PI*.5+TAU*cooldown,48,Color(accent,.8),5,true)
