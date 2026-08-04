extends CanvasLayer

# =============================================================================
#  Server Browser overlay - opened when the main-menu JOIN button is pressed.
#  Lists global public lobbies, supports refresh, join, and private join-by-code.
#  Uses the game's whitrabt font + a hacker-green terminal palette; action
#  buttons are grey boxes with a black outline.
# =============================================================================

const MPSBUI = preload("res://mods-unpacked/Jaxon-PartyFinder/ui/mpsb_ui.gd")
const CORE = preload("res://mods-unpacked/Jaxon-PartyFinder/server_browser.gd")

const HACK_GREEN := Color(0.55, 1.0, 0.55)
const GREY_NORMAL := Color(0.55, 0.55, 0.55)
const GREY_HOVER := Color(0.72, 0.72, 0.72)
const GREY_PRESSED := Color(0.40, 0.40, 0.40)
const GREY_DISABLED := Color(0.30, 0.30, 0.30)

signal closed()

var _root: Control
var _list_container: VBoxContainer
var _status_label: Label
var _code_edit: LineEdit
var _code_error_label: Label
var _refresh_button: Button
var _first_focus: Control


func _ready() -> void:
	layer = 50
	_build_ui()

	if CORE.instance:
		if not CORE.instance.lobbies_refreshed.is_connected(_on_lobbies_refreshed):
			CORE.instance.lobbies_refreshed.connect(_on_lobbies_refreshed)
		CORE.instance.start_browsing()
		_set_status("Searching for lobbies...")
	else:
		_set_status("Server browser unavailable.")

	if CursorManager:
		CursorManager.set_active(true)
		CursorManager.set_locked(false)
		CursorManager.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ---- styling helpers ---------------------------------------------------------

func _grey_box(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color.BLACK
	s.set_border_width_all(3)
	s.set_corner_radius_all(0)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

# Grey box + black outline + black text for all states.
func _style_box_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _grey_box(GREY_NORMAL))
	b.add_theme_stylebox_override("hover", _grey_box(GREY_HOVER))
	b.add_theme_stylebox_override("pressed", _grey_box(GREY_PRESSED))
	b.add_theme_stylebox_override("focus", _grey_box(GREY_HOVER))
	b.add_theme_stylebox_override("disabled", _grey_box(GREY_DISABLED))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.5))

func _green(l: Label) -> void:
	l.add_theme_color_override("font_color", HACK_GREEN)


func _build_ui() -> void:
	# dim backdrop (slightly green-black) that also blocks clicks to the menu behind.
	# Kept light enough that the translucent window lets the menu show through a bit.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MPSBUI.apply_menu_theme(_root)
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	# window with a dark green terminal background + green outline
	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(760, 620)
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.03, 0.07, 0.03, 0.70)   # slightly transparent
	win_style.border_color = HACK_GREEN
	win_style.set_border_width_all(2)
	win_style.set_corner_radius_all(0)
	window.add_theme_stylebox_override("panel", win_style)
	center.add_child(window)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# --- title row: X (top-left) + title + REFRESH (top-right) ---
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var close_x := MPSBUI.make_symbol_button("✕")
	close_x.custom_minimum_size = Vector2(44, 44)
	_style_box_button(close_x)
	close_x.pressed.connect(close)
	title_row.add_child(close_x)

	var title := MPSBUI.make_label("SERVER BROWSER", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_green(title)
	title_row.add_child(title)

	_refresh_button = MPSBUI.make_button("REFRESH")
	_refresh_button.custom_minimum_size = Vector2(120, 44)
	_style_box_button(_refresh_button)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	title_row.add_child(_refresh_button)

	# --- column header ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)
	var h_name := MPSBUI.make_label("LOBBY", 20)
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_green(h_name)
	header.add_child(h_name)
	var h_players := MPSBUI.make_label("PLAYERS", 20)
	h_players.custom_minimum_size = Vector2(110, 0)
	h_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_green(h_players)
	header.add_child(h_players)
	var h_spacer := Control.new()
	h_spacer.custom_minimum_size = Vector2(120, 0)
	header.add_child(h_spacer)

	# --- scrollable lobby list ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_container)

	# --- status line ---
	_status_label = MPSBUI.make_label("", 18)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_green(_status_label)
	vbox.add_child(_status_label)

	vbox.add_child(HSeparator.new())

	# --- join by room-id code (private lobbies) ---
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 10)
	vbox.add_child(code_row)

	var code_label := MPSBUI.make_label("ROOM ID:", 18)
	_green(code_label)
	code_row.add_child(code_label)

	_code_edit = MPSBUI.make_line_edit("paste an 18-digit room code")
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.add_theme_color_override("font_color", HACK_GREEN)
	_code_edit.add_theme_color_override("font_placeholder_color", Color(0.55, 1.0, 0.55, 0.5))
	var le_style := StyleBoxFlat.new()
	le_style.bg_color = Color(0.02, 0.05, 0.02)
	le_style.border_color = Color(0.3, 0.7, 0.3)
	le_style.set_border_width_all(1)
	le_style.set_corner_radius_all(0)
	le_style.content_margin_left = 8
	le_style.content_margin_right = 8
	le_style.content_margin_top = 6
	le_style.content_margin_bottom = 6
	_code_edit.add_theme_stylebox_override("normal", le_style)
	_code_edit.add_theme_stylebox_override("focus", le_style)
	code_row.add_child(_code_edit)

	var paste_button := MPSBUI.make_button("PASTE")
	paste_button.custom_minimum_size = Vector2(110, 44)
	_style_box_button(paste_button)
	paste_button.pressed.connect(func(): _code_edit.text = DisplayServer.clipboard_get())
	code_row.add_child(paste_button)

	# clear separation between PASTE and JOIN so they read as distinct actions
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(28, 0)
	code_row.add_child(gap)

	var join_code_button := MPSBUI.make_button("JOIN")
	join_code_button.custom_minimum_size = Vector2(110, 44)
	_style_box_button(join_code_button)
	join_code_button.pressed.connect(_on_join_by_code_pressed)
	code_row.add_child(join_code_button)

	_code_error_label = MPSBUI.make_label("", 16)
	_code_error_label.modulate = Color.CRIMSON
	_code_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_code_error_label)

	# --- bottom button ---
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var back_button := MPSBUI.make_button("BACK")
	back_button.custom_minimum_size = Vector2(180, 44)
	_style_box_button(back_button)
	back_button.pressed.connect(close)
	buttons.add_child(back_button)

	_first_focus = back_button


func _on_refresh_pressed() -> void:
	if CORE.instance:
		CORE.instance.refresh_lobbies()
		_set_status("Searching for lobbies...")


func _on_join_by_code_pressed() -> void:
	_code_error_label.text = ""
	if not CORE.instance:
		return
	var err: String = CORE.instance.join_by_code(_code_edit.text)
	if err != "":
		_code_error_label.text = tr(err) if err.begins_with("LOC_") else err
	else:
		close()   # scene change is happening; remove this root-level overlay


func _on_lobbies_refreshed(lobbies: Array) -> void:
	for c in _list_container.get_children():
		c.queue_free()

	if lobbies.is_empty():
		_set_status("No public lobbies found. Host one and make it public!")
		return
	_set_status("")

	for info in lobbies:
		_list_container.add_child(_make_row(info))


func _make_row(info: Dictionary) -> Control:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.10, 0.20, 0.10, 0.45)
	row_style.border_color = Color(0.3, 0.7, 0.3, 0.6)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(0)
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.add_child(hbox)
	row.add_child(pad)

	var name_label := MPSBUI.make_label(String(info.get("name", "Lobby")), 22)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_green(name_label)
	hbox.add_child(name_label)

	if not info.get("compatible", true):
		name_label.modulate = Color(1, 1, 1, 0.5)
		var ver := MPSBUI.make_label("v.mismatch", 14)
		ver.modulate = Color.CRIMSON
		hbox.add_child(ver)

	var players_label := MPSBUI.make_label("%d/%d" % [int(info.get("players", 1)), int(info.get("max", 4))], 22)
	players_label.custom_minimum_size = Vector2(110, 0)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_green(players_label)
	hbox.add_child(players_label)

	var join_button := MPSBUI.make_button("JOIN")
	join_button.custom_minimum_size = Vector2(120, 44)
	_style_box_button(join_button)
	var joinable: bool = bool(info.get("joinable", true)) and bool(info.get("compatible", true))
	join_button.disabled = not joinable
	var lobby_id: int = int(info.get("id", 0))
	join_button.pressed.connect(func():
		if CORE.instance:
			close()   # remove this root-level overlay before the scene changes
			CORE.instance.join_lobby(lobby_id)
	)
	hbox.add_child(join_button)

	return row


func _set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	_teardown()
	closed.emit()
	queue_free()


func _teardown() -> void:
	if CORE.instance:
		CORE.instance.stop_browsing()
		if CORE.instance.lobbies_refreshed.is_connected(_on_lobbies_refreshed):
			CORE.instance.lobbies_refreshed.disconnect(_on_lobbies_refreshed)
