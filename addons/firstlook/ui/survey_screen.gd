## FirstLook Survey Screen
## Handles all FirstLook question types:
##   single_select, multi_select, rating, nps, sentiment, text_area, yes_no, matrix
##
## Setup:
##   1. Add survey_screen.tscn to your scene as a CanvasLayer.
##   2. Connect FirstLook.surveys.survey_available to show_survey().
##
## Example:
##   FirstLook.surveys.survey_available.connect($SurveyScreen.show_survey)

extends CanvasLayer

## Emitted when the player submits their responses.
signal survey_submitted

## Emitted when the player dismisses the survey without submitting.
signal survey_dismissed

# --- Theme colors ---
const COLOR_BG         := Color(0.10, 0.10, 0.12, 0.97)
const COLOR_PANEL      := Color(0.15, 0.15, 0.18, 1.0)
const COLOR_ACCENT     := Color(0.27, 0.60, 1.0,  1.0)
const COLOR_ACCENT_HOV := Color(0.37, 0.70, 1.0,  1.0)
const COLOR_SELECTED   := Color(0.20, 0.45, 0.85, 1.0)
const COLOR_TEXT       := Color(0.92, 0.92, 0.95, 1.0)
const COLOR_SUBTEXT    := Color(0.60, 0.60, 0.65, 1.0)
const COLOR_INPUT_BG   := Color(0.12, 0.12, 0.15, 1.0)
const COLOR_BORDER     := Color(0.28, 0.28, 0.33, 1.0)

# Sentiment emoji options
const SENTIMENT_OPTIONS := ["😡", "😞", "😐", "🙂", "😍"]
const SENTIMENT_LABELS  := ["Hate it", "Dislike it", "It's ok", "Like it", "Love it"]

var _survey_data: Dictionary = {}
var _responses: Dictionary = {}  # questionId -> value

var _overlay: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _page_label: Label
var _submit_btn: Button
var _dismiss_btn: Button

func _ready() -> void:
	_build_base_ui()
	hide()

# --- Public API ---

func show_survey(data: Dictionary) -> void:
	_survey_data = data
	_responses = {}
	_populate_questions()
	show()

# --- UI Construction ---

func _build_base_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.anchors_preset = Control.PRESET_CENTER
	_panel.custom_minimum_size = Vector2(560, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_color = COLOR_BORDER
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.content_margin_left   = 32
	style.content_margin_right  = 32
	style.content_margin_top    = 28
	style.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(outer_vbox)

	# Header row
	var header := HBoxContainer.new()
	outer_vbox.add_child(header)

	var title_label := Label.new()
	title_label.text = _survey_data.get("title", "Quick Survey")
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	_dismiss_btn = Button.new()
	_dismiss_btn.text = "✕"
	_dismiss_btn.flat = true
	_dismiss_btn.add_theme_color_override("font_color", COLOR_SUBTEXT)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	header.add_child(_dismiss_btn)

	# Page tracker label
	_page_label = Label.new()
	_page_label.add_theme_color_override("font_color", COLOR_SUBTEXT)
	_page_label.add_theme_font_size_override("font_size", 12)
	outer_vbox.add_child(_page_label)

	# Scrollable question area
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = 360
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 24)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_vbox)

	# Submit button
	_submit_btn = Button.new()
	_submit_btn.text = "Submit"
	_submit_btn.custom_minimum_size.y = 44
	_apply_accent_button_style(_submit_btn)
	_submit_btn.pressed.connect(_on_submit_pressed)
	outer_vbox.add_child(_submit_btn)

func _populate_questions() -> void:
	# Update title in case show_survey was called after _ready
	if _panel and _panel.get_child_count() > 0:
		var ov = _panel.get_child(0)
		if ov.get_child_count() > 0:
			var header = ov.get_child(0)
			if header.get_child_count() > 0:
				header.get_child(0).text = _survey_data.get("title", "Quick Survey")

	for child in _vbox.get_children():
		child.queue_free()

	var questions: Array = _survey_data.get("questions", [])
	_page_label.text = "%d question%s" % [questions.size(), "s" if questions.size() != 1 else ""]

	for q in questions:
		_vbox.add_child(_build_question(q))

func _build_question(q: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 12)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Question text
	var label := Label.new()
	label.text = q.get("text", "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_font_size_override("font_size", 14)
	container.add_child(label)

	# Optional description
	if q.has("description") and q["description"] != "":
		var desc := Label.new()
		desc.text = q["description"]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", COLOR_SUBTEXT)
		desc.add_theme_font_size_override("font_size", 12)
		container.add_child(desc)

	var qid: String = q.get("id", "")
	var qtype: String = q.get("type", "text_area")
	var options: Array = q.get("options", [])

	match qtype:
		"single_select":
			container.add_child(_build_single_select(qid, options))
		"multi_select":
			container.add_child(_build_multi_select(qid, options))
		"rating":
			container.add_child(_build_rating(qid, q.get("max", 5)))
		"nps":
			container.add_child(_build_nps(qid))
		"sentiment":
			container.add_child(_build_sentiment(qid))
		"yes_no":
			container.add_child(_build_yes_no(qid))
		"matrix":
			container.add_child(_build_matrix(qid, q.get("rows", []), q.get("columns", [])))
		_:  # text_area and fallback
			container.add_child(_build_text_area(qid, q.get("placeholder", "Your answer...")))

	return container

# --- Question Type Builders ---

func _build_single_select(qid: String, options: Array) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var group := ButtonGroup.new()
	for opt in options:
		var btn := _make_option_button(opt.get("label", str(opt)), true)
		btn.button_group = group
		btn.toggled.connect(func(pressed):
			if pressed:
				_responses[qid] = opt.get("value", opt.get("label", str(opt)))
		)
		vbox.add_child(btn)

	return vbox

func _build_multi_select(qid: String, options: Array) -> VBoxContainer:
	_responses[qid] = []
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	for opt in options:
		var val = opt.get("value", opt.get("label", str(opt)))
		var btn := _make_option_button(opt.get("label", str(opt)), false)
		btn.toggled.connect(func(pressed):
			if not _responses.has(qid):
				_responses[qid] = []
			if pressed:
				if val not in _responses[qid]:
					_responses[qid].append(val)
			else:
				_responses[qid].erase(val)
		)
		vbox.add_child(btn)

	return vbox

func _build_rating(qid: String, max_stars: int) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var stars: Array[Button] = []
	for i in range(1, max_stars + 1):
		var star := Button.new()
		star.text = "★"
		star.flat = true
		star.add_theme_font_size_override("font_size", 28)
		star.add_theme_color_override("font_color", COLOR_SUBTEXT)
		var idx := i
		star.pressed.connect(func():
			_responses[qid] = idx
			for j in range(stars.size()):
				stars[j].add_theme_color_override("font_color",
					COLOR_ACCENT if j < idx else COLOR_SUBTEXT)
		)
		stars.append(star)
		hbox.add_child(star)

	return hbox

func _build_nps(qid: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var buttons: Array[Button] = []
	for i in range(0, 11):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(42, 42)
		_apply_outline_button_style(btn)
		var val := i
		btn.pressed.connect(func():
			_responses[qid] = val
			for j in range(buttons.size()):
				_apply_outline_button_style(buttons[j])
			_apply_accent_button_style(btn)
		)
		buttons.append(btn)
		hbox.add_child(btn)

	vbox.add_child(hbox)

	var labels_row := HBoxContainer.new()
	labels_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var not_likely := Label.new()
	not_likely.text = "Not likely"
	not_likely.add_theme_color_override("font_color", COLOR_SUBTEXT)
	not_likely.add_theme_font_size_override("font_size", 11)
	labels_row.add_child(not_likely)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels_row.add_child(spacer)

	var very_likely := Label.new()
	very_likely.text = "Very likely"
	very_likely.add_theme_color_override("font_color", COLOR_SUBTEXT)
	very_likely.add_theme_font_size_override("font_size", 11)
	labels_row.add_child(very_likely)

	vbox.add_child(labels_row)
	return vbox

func _build_sentiment(qid: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var btns: Array[Button] = []
	for i in range(SENTIMENT_OPTIONS.size()):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)

		var emoji_btn := Button.new()
		emoji_btn.text = SENTIMENT_OPTIONS[i]
		emoji_btn.flat = true
		emoji_btn.add_theme_font_size_override("font_size", 32)
		var val := i + 1
		emoji_btn.pressed.connect(func():
			_responses[qid] = val
			for b in btns:
				b.add_theme_color_override("font_color", COLOR_SUBTEXT)
			emoji_btn.add_theme_color_override("font_color", COLOR_ACCENT)
		)
		btns.append(emoji_btn)
		col.add_child(emoji_btn)

		var lbl := Label.new()
		lbl.text = SENTIMENT_LABELS[i]
		lbl.add_theme_color_override("font_color", COLOR_SUBTEXT)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)

		hbox.add_child(col)

	return hbox

func _build_yes_no(qid: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	for opt in ["Yes", "No"]:
		var btn := Button.new()
		btn.text = opt
		btn.custom_minimum_size = Vector2(120, 44)
		_apply_outline_button_style(btn)
		var val := opt
		btn.pressed.connect(func():
			_responses[qid] = val
			for child in hbox.get_children():
				_apply_outline_button_style(child)
			_apply_accent_button_style(btn)
		)
		hbox.add_child(btn)

	return hbox

func _build_text_area(qid: String, placeholder: String) -> TextEdit:
	var input := TextEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size.y = 100
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_color_override("font_color", COLOR_TEXT)
	input.add_theme_color_override("background_color", COLOR_INPUT_BG)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT_BG
	style.border_color = COLOR_BORDER
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	input.add_theme_stylebox_override("normal", style)

	input.text_changed.connect(func():
		_responses[qid] = input.text
	)
	return input

func _build_matrix(qid: String, rows: Array, columns: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns.size() + 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Header row. First cell blank.
	var blank := Label.new()
	grid.add_child(blank)

	for col in columns:
		var lbl := Label.new()
		lbl.text = col.get("label", str(col))
		lbl.add_theme_color_override("font_color", COLOR_SUBTEXT)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(lbl)

	# Data rows
	for row in rows:
		var row_label := Label.new()
		row_label.text = row.get("label", str(row))
		row_label.add_theme_color_override("font_color", COLOR_TEXT)
		row_label.add_theme_font_size_override("font_size", 13)
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row_label)

		var row_id: String = row.get("id", row.get("label", str(row)))
		var group := ButtonGroup.new()
		for col in columns:
			var col_val = col.get("value", col.get("label", str(col)))
			var rb := CheckBox.new()
			rb.button_group = group
			rb.alignment = HORIZONTAL_ALIGNMENT_CENTER
			rb.toggled.connect(func(pressed):
				if pressed:
					if not _responses.has(qid):
						_responses[qid] = {}
					_responses[qid][row_id] = col_val
			)
			grid.add_child(rb)

	return grid

# --- Helpers ---

func _make_option_button(text: String, is_radio: bool) -> Button:
	var btn := Button.new()
	btn.text = "  " + text
	btn.toggle_mode = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 40

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_PANEL
	normal.border_color = COLOR_BORDER
	normal.border_width_left   = 1
	normal.border_width_right  = 1
	normal.border_width_top    = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 12

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = COLOR_SELECTED
	pressed_style.border_color = COLOR_ACCENT
	pressed_style.border_width_left   = 2
	pressed_style.border_width_right  = 2
	pressed_style.border_width_top    = 2
	pressed_style.border_width_bottom = 2
	pressed_style.corner_radius_top_left     = 6
	pressed_style.corner_radius_top_right    = 6
	pressed_style.corner_radius_bottom_left  = 6
	pressed_style.corner_radius_bottom_right = 6
	pressed_style.content_margin_left = 12

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT)

	return btn

func _apply_accent_button_style(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _apply_outline_button_style(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 12
	style.content_margin_right  = 12
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", COLOR_TEXT)

# --- Actions ---

func _on_submit_pressed() -> void:
	var survey_id: String = _survey_data.get("id", "")
	var response_array: Array = []

	for qid in _responses:
		response_array.append({ "questionId": qid, "value": _responses[qid] })

	var result = await FirstLook.surveys.submit_response(survey_id, response_array)

	if result.success:
		print("[FirstLook] Survey submitted successfully.")
	else:
		printerr("[FirstLook] Survey submission failed: ", result.get("error", "unknown"))

	survey_submitted.emit()
	hide()

func _on_dismiss_pressed() -> void:
	survey_dismissed.emit()
	hide()
