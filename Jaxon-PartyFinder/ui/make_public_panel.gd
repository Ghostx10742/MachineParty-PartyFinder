extends CanvasLayer

# =============================================================================
#  "Make Lobby Public" popup - lets the host name the lobby and choose a max
#  player count (up/down stepper, hard-capped at 4) before publishing it.
# =============================================================================

const MPSBUI = preload("res://mods-unpacked/Jaxon-PartyFinder/ui/mpsb_ui.gd")
const StepperScript = preload("res://mods-unpacked/Jaxon-PartyFinder/ui/max_players_stepper.gd")

signal confirmed(lobby_name, max_players)
signal cancelled()

var _name_edit: LineEdit
var _stepper: HBoxContainer

var initial_name: String = ""
var initial_max: int = 4


func _ready() -> void:
	layer = 60
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MPSBUI.apply_menu_theme(root)
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(560, 0)
	center.add_child(window)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := MPSBUI.make_label("MAKE LOBBY PUBLIC", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(MPSBUI.make_label("LOBBY NAME", 18))
	_name_edit = MPSBUI.make_line_edit("Lobby name")
	_name_edit.text = initial_name
	_name_edit.max_length = 63
	vbox.add_child(_name_edit)

	vbox.add_child(MPSBUI.make_label("MAX PLAYERS", 18))
	_stepper = StepperScript.new()
	# Set the value BEFORE it enters the tree so _ready() renders the right number.
	_stepper.set_value(initial_max)
	vbox.add_child(_stepper)

	vbox.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var confirm := MPSBUI.make_button("CONFIRM")
	confirm.custom_minimum_size = Vector2(200, 0)
	confirm.pressed.connect(_on_confirm)
	buttons.add_child(confirm)

	var cancel := MPSBUI.make_button("CANCEL")
	cancel.custom_minimum_size = Vector2(200, 0)
	cancel.pressed.connect(_on_cancel)
	buttons.add_child(cancel)


func _on_confirm() -> void:
	var lobby_name := _name_edit.text
	var max_players := 4
	if is_instance_valid(_stepper):
		max_players = _stepper.value
	confirmed.emit(lobby_name, max_players)
	queue_free()


func _on_cancel() -> void:
	cancelled.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
