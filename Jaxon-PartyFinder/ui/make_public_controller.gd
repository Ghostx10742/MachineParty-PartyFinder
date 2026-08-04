extends Node

# =============================================================================
#  Drives the "Make Lobby Public" toggle. This node is added as a CHILD of a
#  button that was DUPLICATED from a native lobby button (Copy Room ID / Invite),
#  so the toggle inherits the game's exact font / size / color / style. We only
#  set its text and behaviour here. Lives/dies with that button.
# =============================================================================

const CORE := preload("res://mods-unpacked/Jaxon-PartyFinder/server_browser.gd")
const PanelScene := preload("res://mods-unpacked/Jaxon-PartyFinder/ui/make_public_panel.gd")

const TEXT_PRIVATE := "MAKE LOBBY PUBLIC"
const TEXT_PUBLIC := "MAKE LOBBY PRIVATE"

var _button: Button
var _panel_open := false


func _ready() -> void:
	_button = get_parent() as Button
	if not is_instance_valid(_button):
		return
	_button.pressed.connect(_on_pressed)
	if CORE.instance:
		CORE.instance.publish_state_changed.connect(_on_state_changed)
	_refresh_text(_is_public())


func _is_public() -> bool:
	return CORE.instance != null and CORE.instance.is_owned_lobby_public()


func _on_pressed() -> void:
	if not CORE.instance or CORE.instance.get_owned_lobby_id() <= 0:
		return
	if _is_public():
		CORE.instance.unpublish()
	else:
		_open_panel()


func _open_panel() -> void:
	if _panel_open:
		return
	_panel_open = true
	var panel := PanelScene.new()
	panel.initial_name = "%s's lobby" % Steam.getFriendPersonaName(Steam.getSteamID())
	var current_max := NetworkManager.max_player_count
	panel.initial_max = clampi(current_max, 1, CORE.MAX_PLAYERS_CAP) if current_max > 0 else CORE.MAX_PLAYERS_CAP
	get_tree().root.add_child(panel)
	panel.confirmed.connect(func(lobby_name, max_players):
		_panel_open = false
		if CORE.instance:
			CORE.instance.publish(lobby_name, max_players)
	)
	panel.cancelled.connect(func():
		_panel_open = false
	)


func _on_state_changed(is_public: bool) -> void:
	_refresh_text(is_public)


func _refresh_text(is_public: bool) -> void:
	if is_instance_valid(_button):
		_button.text = TEXT_PUBLIC if is_public else TEXT_PRIVATE
