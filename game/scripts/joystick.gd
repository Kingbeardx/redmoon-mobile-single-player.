extends Control
## Multitouch movement pad. Touch index is independent of attack/heal controls.
var direction: Vector2 = Vector2.ZERO
var active_touch: int = -1
var mouse_dragging: bool = false
const RADIUS: float = 58.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(156, 156)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1 and get_global_rect().has_point(event.position):
			active_touch = event.index
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			direction = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and active_touch == -1:
		if event.pressed and get_global_rect().has_point(event.position):
			mouse_dragging = true
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_dragging:
			mouse_dragging = false
			direction = Vector2.ZERO
			queue_redraw()
	elif event is InputEventMouseMotion and mouse_dragging:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		direction = Vector2.ZERO
		active_touch = -1
		mouse_dragging = false
		queue_redraw()

func _update_direction(global_point: Vector2) -> void:
	direction = ((global_point - global_position - size * 0.5) / RADIUS).limit_length(1.0)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, 72.0, Color(0.045, 0.065, 0.09, 0.93))
	draw_arc(center, 72.0, 0, TAU, 60, Color(0.27, 0.34, 0.43, 0.8), 1.5, true)
	draw_arc(center, 48.0, 0, TAU, 50, Color(0.19, 0.25, 0.32, 0.8), 1.0, true)
	draw_line(center + Vector2(-60, 0), center + Vector2(-51, 0), Color(0.45, 0.52, 0.61), 2)
	draw_line(center + Vector2(60, 0), center + Vector2(51, 0), Color(0.45, 0.52, 0.61), 2)
	draw_line(center + Vector2(0, -60), center + Vector2(0, -51), Color(0.45, 0.52, 0.61), 2)
	draw_line(center + Vector2(0, 60), center + Vector2(0, 51), Color(0.45, 0.52, 0.61), 2)
	var knob: Vector2 = center + direction * 43.0
	draw_circle(knob + Vector2(0, 3), 26, Color(0, 0, 0, 0.3))
	draw_circle(knob, 25, Color(0.26, 0.32, 0.4))
	draw_arc(knob, 25, 0, TAU, 40, Color(0.57, 0.66, 0.76), 1.5, true)
	draw_circle(knob, 4, Color(0.86, 0.89, 0.93))
