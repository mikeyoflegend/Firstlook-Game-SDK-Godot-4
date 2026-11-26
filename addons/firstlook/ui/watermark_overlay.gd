## FirstLook Playtest Watermark
## Draws the session code faintly across the screen when FirstLook has
## watermarking turned on for your game (Playtest Watermark on the SDK
## configuration page). If a screenshot or video leaks, you can search the
## code on FirstLook's watermark page to find the session.
##
## Setup: drag addons/firstlook/ui/watermark_overlay.tscn into your main
## scene, or add a CanvasLayer and attach this script. It stays hidden
## until FirstLook says watermarking is on.

class_name FirstLookWatermarkOverlay
extends CanvasLayer

@export var color: Color = Color(1, 1, 1)
@export_range(0.0, 1.0) var opacity: float = 0.06
## How many copies of the code across the screen width (1 to 12).
@export_range(1, 12) var tile_density: int = 5
@export var angle_degrees: float = 30.0
## Slow drift so the code is harder to crop out. 0 turns it off.
@export var drift_speed: float = 0.5
@export var include_center: bool = true
@export var font_size: int = 22

var code: String = ""
var _canvas: Control
var _time: float = 0.0

func _ready() -> void:
	layer = max(layer, 120)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_tiles)
	add_child(_canvas)
	hide()

	var sdk := get_node_or_null("/root/FirstLook")
	if sdk != null and sdk.has_signal("watermark_enabled"):
		sdk.connect("watermark_enabled", show_code)
		if str(sdk.get("watermark_code")) != "":
			show_code(str(sdk.get("watermark_code")))

func show_code(session_code: String) -> void:
	code = session_code
	visible = code != ""
	_canvas.queue_redraw()

func _process(delta: float) -> void:
	if visible and drift_speed > 0.0:
		_time += delta
		_canvas.queue_redraw()

func _draw_tiles() -> void:
	if code == "":
		return
	var font := ThemeDB.fallback_font
	var size := _canvas.get_viewport_rect().size
	var c := Color(color.r, color.g, color.b, opacity)
	var step := size.x / float(clampi(tile_density, 1, 12))
	var offset := fmod(_time * drift_speed * 20.0, step)

	_canvas.draw_set_transform(size / 2.0, deg_to_rad(-angle_degrees), Vector2.ONE)
	var reach := size.length()
	var y := -reach / 2.0
	var row := 0
	while y < reach / 2.0:
		var x := -reach / 2.0 + offset + (step / 2.0 if row % 2 == 1 else 0.0)
		while x < reach / 2.0:
			_canvas.draw_string(font, Vector2(x, y), code, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
			x += step
		y += step * 0.6
		row += 1
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if include_center:
		var big := font_size * 2
		var w := font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		_canvas.draw_string(font, Vector2((size.x - w) / 2.0, size.y / 2.0), code, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(c, min(1.0, opacity * 1.5)))
