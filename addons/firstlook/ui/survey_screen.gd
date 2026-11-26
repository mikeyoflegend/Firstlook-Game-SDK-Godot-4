## FirstLook Survey Screen
## A ready-made, dark-themed UI for FirstLook's paged in-game surveys.
##
## Native question kinds it draws:
##   block (text), image, textarea, single_select, multi_select,
##   rating, n_p_s, sentiment (opinion scale), yes_no
## Matrix, image choice, and video questions are web-only in FirstLook,
## so surveys that use them arrive on browser_survey_available instead.
##
## Setup (pick one):
##   A. Drag addons/firstlook/ui/survey_screen.tscn into your main scene.
##   B. Add a CanvasLayer node and attach this script to it.
## With auto_connect on (default) it shows surveys by itself. Just fire
## triggers with FirstLook.surveys.post_trigger_event("match.completed").

class_name FirstLookSurveyScreen
extends CanvasLayer

## A page was sent to FirstLook.
signal page_submitted(page_index: int)

## The whole survey was finished.
signal survey_completed

## The player closed the survey before finishing.
signal survey_dismissed

## Kept for older code: emitted together with survey_completed.
signal survey_submitted

## Show surveys automatically when FirstLook sends one.
@export var auto_connect: bool = true

## Make the mouse cursor visible while the survey is open, then put it
## back the way it was. Helpful for games that capture the mouse.
@export var show_mouse_cursor: bool = true

# --- Theme colors ---
const COLOR_BG         := Color(0.10, 0.10, 0.12, 0.97)
const COLOR_PANEL      := Color(0.15, 0.15, 0.18, 1.0)
const COLOR_ACCENT     := Color(0.27, 0.60, 1.0,  1.0)
const COLOR_SELECTED   := Color(0.20, 0.45, 0.85, 1.0)
const COLOR_TEXT       := Color(0.92, 0.92, 0.95, 1.0)
const COLOR_SUBTEXT    := Color(0.60, 0.60, 0.65, 1.0)
const COLOR_INPUT_BG   := Color(0.12, 0.12, 0.15, 1.0)
const COLOR_BORDER     := Color(0.28, 0.28, 0.33, 1.0)
const COLOR_ERROR      := Color(1.0,  0.45, 0.45, 1.0)

const SENTIMENT_EMOJIS := ["😡", "😞", "😐", "🙂", "😍"]
const RATING_ICONS := { "star": "★", "heart": "♥", "smile": "☺", "thumbs_up": "👍", "thumbsup": "👍" }

var _page_response: Dictionary = {}
var _answers: Dictionary = {}       # question uuid -> value, all pages so far
var _questions: Array = []          # questions on the current page
var _question_nodes: Dictionary = {} # question uuid -> Control
var _busy: bool = false
var _saved_mouse_mode: int = -1

var _title_label: Label
var _page_label: Label
var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _error_label: Label
var _next_btn: Button

func _ready() -> void:
	layer = max(layer, 100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_base_ui()
	hide()
	if auto_connect:
		var sdk := get_node_or_null("/root/FirstLook")
		if sdk != null and sdk.has_signal("survey_available"):
			sdk.connect("survey_available", show_survey)

# --- Public API ---

## Show a survey page response from FirstLook.
func show_survey(page_response: Dictionary) -> void:
	if page_response.is_empty() or page_response.get("page") == null:
		return
	if not visible:
		_answers = {}
		if show_mouse_cursor:
			_saved_mouse_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_page_response = page_response
	_render_page()
	show()

func close() -> void:
	hide()
	_page_response = {}
	if _saved_mouse_mode != -1:
		Input.mouse_mode = _saved_mouse_mode as Input.MouseMode
		_saved_mouse_mode = -1

# --- Layout ---

func _build_base_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var style := _box(COLOR_BG, COLOR_BORDER, 1, 12)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)

	_title_label = _label("Quick Survey", 20, COLOR_TEXT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_title_label)

	var dismiss := Button.new()
	dismiss.text = "✕"
	dismiss.flat = true
	dismiss.tooltip_text = "Close"
	dismiss.add_theme_color_override("font_color", COLOR_SUBTEXT)
	dismiss.pressed.connect(_on_dismiss_pressed)
	header.add_child(dismiss)

	_page_label = _label("", 12, COLOR_SUBTEXT)
	outer.add_child(_page_label)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 380)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	# Right margin keeps content clear of the scrollbar.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 16)
	_scroll.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 26)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_vbox)

	_error_label = _label("", 13, COLOR_ERROR)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.hide()
	outer.add_child(_error_label)

	_next_btn = Button.new()
	_next_btn.text = "Next"
	_next_btn.custom_minimum_size.y = 44
	_style_accent(_next_btn)
	_next_btn.pressed.connect(_on_next_pressed)
	outer.add_child(_next_btn)

func _render_page() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_question_nodes = {}
	_error_label.hide()

	var survey: Dictionary = _page_response.get("survey", {})
	var page: Dictionary = _page_response.get("page", {})
	_title_label.text = str(survey.get("name", "Quick Survey"))

	var total := FirstLookSurveys.get_page_count(_page_response)
	var index_v: Variant = _page_response.get("page_index")
	var index: int = int(index_v) if index_v != null else 0
	var is_last := total > 0 and index >= total - 1
	_page_label.text = "Page %d of %d" % [index + 1, total] if total > 1 else ""
	_page_label.visible = _page_label.text != ""
	_next_btn.text = "Submit" if (is_last or total <= 1) else "Next"
	_next_btn.disabled = false

	var page_title := str(page.get("title", ""))
	var page_desc := str(page.get("description", "")) if page.get("description") != null else ""
	if (page_title != "" and page_title != _title_label.text) or page_desc != "":
		var head := VBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		if page_title != "" and page_title != _title_label.text:
			head.add_child(_label(page_title, 17, COLOR_TEXT))
		if page_desc != "":
			var d := _label(page_desc, 13, COLOR_SUBTEXT)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			head.add_child(d)
		_vbox.add_child(head)

	_questions = page.get("questions", [])
	for q in _questions:
		var node := _build_question(q)
		if node != null:
			_question_nodes[str(q.get("uuid", ""))] = node
			_vbox.add_child(node)
	_refresh_conditions()
	_scroll.scroll_vertical = 0

func _show_completion() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_question_nodes = {}
	_error_label.hide()
	_page_label.hide()

	var msg := FirstLookSurveys.get_completion_message(_page_response)
	var title := str(msg.get("title", "Thanks for your feedback!"))
	var body := str(msg.get("body", "Your answers were sent."))
	_vbox.add_child(_label(title, 18, COLOR_TEXT))
	var b := _label(body, 14, COLOR_SUBTEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(b)
	_next_btn.text = "Close"
	_next_btn.disabled = false

# --- Questions ---

func _build_question(q: Dictionary) -> Control:
	var kind := str(q.get("kind", ""))
	var qid := str(q.get("uuid", ""))
	var cfg: Dictionary = q.get("config", {}) if q.get("config") is Dictionary else {}
	var required: bool = cfg.get("required", false) == true

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := _text(q, "title")
	if title != "":
		var t := _label(title + ("  *" if required and kind != "block" else ""), 15, COLOR_TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(t)
	for key in ["subtitle", "description"]:
		var extra := _text(q, key)
		if extra != "":
			var e := _label(extra, 12, COLOR_SUBTEXT)
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(e)

	var options: Array = q.get("options", []) if q.get("options") is Array else []

	match kind:
		"block":
			pass
		"image":
			box.add_child(_build_image(_text(q, "url")))
		"textarea":
			box.add_child(_build_text(qid, cfg.get("multiple_lines", false) == true))
		"single_select":
			box.add_child(_build_choices(qid, options, false, cfg))
		"multi_select":
			box.add_child(_build_choices(qid, options, true, cfg))
		"rating":
			box.add_child(_build_rating(qid, _int(cfg.get("scale"), 5), str(cfg.get("icon", "star"))))
		"n_p_s":
			box.add_child(_build_scale(qid, 0, 10, "Not likely", "Very likely", false))
		"sentiment":
			var n := _int(cfg.get("scale"), 5)
			var labels: bool = cfg.get("show_labels", true) != false
			box.add_child(_build_scale(qid, 1, n, "Strongly disagree" if labels else "", "Strongly agree" if labels else "", cfg.get("use_emojis", false) == true))
		"yes_no":
			box.add_child(_build_yes_no(qid))
		_:
			var note := _label("(This question can only be answered in the browser version of the survey.)", 12, COLOR_SUBTEXT)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(note)

	return box

func _build_text(qid: String, multi_line: bool) -> Control:
	var style := _box(COLOR_INPUT_BG, COLOR_BORDER, 1, 6)
	style.set_content_margin_all(10)
	if multi_line:
		var te := TextEdit.new()
		te.custom_minimum_size.y = 110
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.placeholder_text = "Your answer..."
		te.add_theme_stylebox_override("normal", style)
		te.add_theme_color_override("font_color", COLOR_TEXT)
		te.text = str(_answers.get(qid, ""))
		te.text_changed.connect(func() -> void: _set_answer(qid, te.text.strip_edges()))
		return te
	var le := LineEdit.new()
	le.custom_minimum_size.y = 40
	le.placeholder_text = "Your answer..."
	le.add_theme_stylebox_override("normal", style)
	le.add_theme_color_override("font_color", COLOR_TEXT)
	le.text = str(_answers.get(qid, ""))
	le.text_changed.connect(func(t: String) -> void: _set_answer(qid, t.strip_edges()))
	return le

func _build_choices(qid: String, options: Array, multiple: bool, cfg: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	var group: ButtonGroup = null if multiple else ButtonGroup.new()
	var max_sel: int = _int(cfg.get("max_selections"), 0)
	var selected: Array = []
	var other_text := { "value": "" }
	var buttons: Array[Button] = []

	var other_edit := LineEdit.new()
	other_edit.placeholder_text = "Type your answer..."
	other_edit.custom_minimum_size.y = 38
	other_edit.add_theme_color_override("font_color", COLOR_TEXT)
	var other_style := _box(COLOR_INPUT_BG, COLOR_BORDER, 1, 6)
	other_style.set_content_margin_all(8)
	other_edit.add_theme_stylebox_override("normal", other_style)
	other_edit.hide()

	var publish := func() -> void:
		var values: Array = selected.duplicate()
		var other_i := values.find("__other__")
		if other_i != -1:
			values.remove_at(other_i)
			if str(other_text.value) != "":
				values.append(str(other_text.value))
		if multiple:
			_set_answer(qid, values if not values.is_empty() else null)
		else:
			_set_answer(qid, values[0] if not values.is_empty() else null)

	var entries: Array = []
	for opt in options:
		if opt is Dictionary:
			entries.append({ "label": str(opt.get("label", opt.get("value", ""))), "value": str(opt.get("value", opt.get("label", ""))) })
		else:
			entries.append({ "label": str(opt), "value": str(opt) })
	if cfg.get("other", false) == true:
		entries.append({ "label": "Other", "value": "__other__" })

	for entry in entries:
		var value: String = entry.value
		var btn := _option_button(entry.label)
		if group != null:
			btn.button_group = group
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				if not multiple:
					selected.clear()
				if max_sel > 0 and selected.size() >= max_sel:
					btn.set_pressed_no_signal(false)
					_show_error("You can pick up to %d." % max_sel)
					return
				if not selected.has(value):
					selected.append(value)
			else:
				selected.erase(value)
			other_edit.visible = selected.has("__other__")
			publish.call()
		)
		buttons.append(btn)
		vbox.add_child(btn)

	other_edit.text_changed.connect(func(t: String) -> void:
		other_text.value = t.strip_edges()
		publish.call()
	)
	vbox.add_child(other_edit)
	return vbox

func _build_rating(qid: String, count: int, icon: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var symbol: String = RATING_ICONS.get(icon.to_lower(), "★")
	var stars: Array[Button] = []
	for i in range(1, count + 1):
		var star := Button.new()
		star.text = symbol
		star.flat = true
		star.tooltip_text = str(i)
		star.add_theme_font_size_override("font_size", 30)
		star.add_theme_color_override("font_color", COLOR_SUBTEXT)
		var val: int = i
		star.pressed.connect(func() -> void:
			_set_answer(qid, val)
			for j in range(stars.size()):
				var c: Color = COLOR_ACCENT if j < val else COLOR_SUBTEXT
				stars[j].add_theme_color_override("font_color", c)
				stars[j].add_theme_color_override("font_hover_color", c)
		)
		stars.append(star)
		hbox.add_child(star)
	return hbox

func _build_scale(qid: String, low: int, high: int, low_label: String, high_label: String, emojis: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var buttons: Array[Button] = []
	var steps := high - low + 1
	for i in range(low, high + 1):
		var btn := Button.new()
		if emojis:
			var e_index := int(round(float(i - low) / max(1, steps - 1) * (SENTIMENT_EMOJIS.size() - 1)))
			btn.text = SENTIMENT_EMOJIS[e_index]
			btn.add_theme_font_size_override("font_size", 24)
		else:
			btn.text = str(i)
		btn.custom_minimum_size = Vector2(40 if steps > 7 else 48, 44)
		_style_outline(btn)
		var val: int = i
		btn.pressed.connect(func() -> void:
			_set_answer(qid, val)
			for b in buttons:
				_style_outline(b)
			_style_accent(btn)
		)
		buttons.append(btn)
		row.add_child(btn)
	vbox.add_child(row)

	if low_label != "" or high_label != "":
		var labels := HBoxContainer.new()
		labels.add_child(_label(low_label, 11, COLOR_SUBTEXT))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.add_child(spacer)
		labels.add_child(_label(high_label, 11, COLOR_SUBTEXT))
		vbox.add_child(labels)
	return vbox

func _build_yes_no(qid: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	var buttons: Array[Button] = []
	for pair in [["Yes", true], ["No", false]]:
		var btn := Button.new()
		btn.text = pair[0]
		btn.custom_minimum_size = Vector2(120, 44)
		_style_outline(btn)
		var val: bool = pair[1]
		btn.pressed.connect(func() -> void:
			_set_answer(qid, val)
			for b in buttons:
				_style_outline(b)
			_style_accent(btn)
		)
		buttons.append(btn)
		hbox.add_child(btn)
	return hbox

func _build_image(url: String) -> Control:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0, 200)
	if url == "":
		return rect
	var req := HTTPRequest.new()
	rect.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var img := Image.new()
		if img.load_png_from_buffer(body) == OK or img.load_jpg_from_buffer(body) == OK or img.load_webp_from_buffer(body) == OK:
			rect.texture = ImageTexture.create_from_image(img)
	)
	req.request.call_deferred(url)
	return rect

# --- Answers and conditions ---

func _set_answer(qid: String, value: Variant) -> void:
	if value == null or (value is String and value == ""):
		_answers.erase(qid)
	else:
		_answers[qid] = value
	_error_label.hide()
	_refresh_conditions()

func _refresh_conditions() -> void:
	for q in _questions:
		var qid := str(q.get("uuid", ""))
		var node: Control = _question_nodes.get(qid)
		if node == null:
			continue
		var show_it := _conditions_met(q)
		node.visible = show_it

func _conditions_met(q: Dictionary) -> bool:
	var conds: Variant = q.get("conditions")
	if not (conds is Array):
		return true
	for c in conds:
		if not (c is Dictionary):
			continue
		var answer: Variant = _answers.get(str(c.get("question_uuid", "")))
		if not _check(answer, str(c.get("operator", "equals")), c.get("value")):
			return false
	return true

func _check(answer: Variant, op: String, target: Variant) -> bool:
	if answer == null:
		return op == "not_equals" or op == "not_contains"
	var a := FirstLookSurveys.encode_answer(answer)
	var t := FirstLookSurveys.encode_answer(target)
	match op:
		"equals":
			return a == t
		"not_equals":
			return a != t
		"greater_than":
			return a.to_float() > t.to_float()
		"greater_than_or_equal":
			return a.to_float() >= t.to_float()
		"less_than":
			return a.to_float() < t.to_float()
		"less_than_or_equal":
			return a.to_float() <= t.to_float()
		"contains":
			return _as_list(answer).has(t) or a.contains(t)
		"not_contains":
			return not (_as_list(answer).has(t) or a.contains(t))
		"contains_any":
			var mine := _as_list(answer)
			for item in _as_list(target):
				if mine.has(item):
					return true
			return false
	return true

func _as_list(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(FirstLookSurveys.encode_answer(x))
	elif v != null:
		out.append(FirstLookSurveys.encode_answer(v))
	return out

func _page_answers() -> Dictionary:
	var out := {}
	for q in _questions:
		var qid := str(q.get("uuid", ""))
		var node: Control = _question_nodes.get(qid)
		if node != null and node.visible and _answers.has(qid):
			out[qid] = _answers[qid]
	return out

func _missing_required() -> String:
	for q in _questions:
		var qid := str(q.get("uuid", ""))
		var node: Control = _question_nodes.get(qid)
		var cfg: Variant = q.get("config")
		var required: bool = cfg is Dictionary and cfg.get("required", false) == true
		if required and q.get("kind") != "block" and node != null and node.visible and not _answers.has(qid):
			var title := _text(q, "title")
			return title if title != "" else "a required question"
	return ""

# --- Actions ---

func _on_next_pressed() -> void:
	if _busy:
		return
	if _question_nodes.is_empty() and _next_btn.text == "Close":
		survey_completed.emit()
		survey_submitted.emit()
		close()
		return

	var missing := _missing_required()
	if missing != "":
		_show_error("Please answer: " + missing)
		return

	var sdk := get_node_or_null("/root/FirstLook")
	if sdk == null or sdk.get("surveys") == null:
		_show_error("FirstLook is not set up.")
		return

	_busy = true
	_next_btn.disabled = true
	_next_btn.text = "Sending..."
	var index_v: Variant = _page_response.get("page_index")
	var index: int = int(index_v) if index_v != null else 0
	var next: Dictionary = await sdk.surveys.submit_page(_page_response, _page_answers())
	_busy = false

	if next.has("error"):
		_next_btn.disabled = false
		_next_btn.text = "Try again"
		_show_error("Could not send your answers. " + str(next.error))
		return

	page_submitted.emit(index)
	if next.get("completed", false) or next.get("page") == null:
		if not next.is_empty():
			_page_response = next
		_show_completion()
	else:
		_page_response = next
		_render_page()

func _on_dismiss_pressed() -> void:
	survey_dismissed.emit()
	close()

func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.show()

# --- Helpers ---

func _text(q: Dictionary, key: String) -> String:
	var v: Variant = q.get(key)
	return str(v) if v != null else ""

func _int(v: Variant, fallback: int) -> int:
	if v == null:
		return fallback
	var n := int(v)
	return n if n > 0 else fallback

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

func _option_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 40
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var normal := _box(COLOR_PANEL, COLOR_BORDER, 1, 6)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 14
	var pressed := _box(COLOR_SELECTED, COLOR_ACCENT, 2, 6)
	pressed.set_content_margin_all(10)
	pressed.content_margin_left = 14
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, COLOR_TEXT)
	return btn

func _style_accent(btn: Button) -> void:
	var s := _box(COLOR_ACCENT, COLOR_ACCENT, 0, 6)
	s.set_content_margin_all(8)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, Color.WHITE)

func _style_outline(btn: Button) -> void:
	var s := _box(COLOR_PANEL, COLOR_BORDER, 1, 6)
	s.set_content_margin_all(8)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, COLOR_TEXT)
