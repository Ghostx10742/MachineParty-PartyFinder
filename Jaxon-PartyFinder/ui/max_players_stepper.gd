extends HBoxContainer

# =============================================================================
#  Max-players stepper: a value with up/down arrows, hard-capped at 4.
#  Any attempt to go above MAX (or below MIN) is simply ignored.
# =============================================================================

const MPSBUI = preload("res://mods-unpacked/Jaxon-PartyFinder/ui/mpsb_ui.gd")

const MIN_VALUE: int = 1
const MAX_VALUE: int = 4          # hard cap per design

signal value_changed(value)

var value: int = MAX_VALUE
var _value_label: Label
var _up_button: Button
var _down_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER

	_value_label = MPSBUI.make_label(str(value), 40)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.custom_minimum_size = Vector2(48, 0)
	add_child(_value_label)

	var arrows := VBoxContainer.new()
	arrows.add_theme_constant_override("separation", 2)
	add_child(arrows)

	_up_button = MPSBUI.make_symbol_button("▲")
	_up_button.custom_minimum_size = Vector2(40, 28)
	_up_button.pressed.connect(func(): _step(1))
	arrows.add_child(_up_button)

	_down_button = MPSBUI.make_symbol_button("▼")
	_down_button.custom_minimum_size = Vector2(40, 28)
	_down_button.pressed.connect(func(): _step(-1))
	arrows.add_child(_down_button)

	_refresh()


func set_value(v: int) -> void:
	value = clampi(v, MIN_VALUE, MAX_VALUE)
	_refresh()


func _step(delta: int) -> void:
	var new_value := clampi(value + delta, MIN_VALUE, MAX_VALUE)
	if new_value == value:
		return          # at cap/floor -> ignore, don't let them exceed
	value = new_value
	_refresh()
	value_changed.emit(value)


func _refresh() -> void:
	if not is_instance_valid(_value_label):
		return
	_value_label.text = str(value)
	_up_button.disabled = value >= MAX_VALUE
	_down_button.disabled = value <= MIN_VALUE
