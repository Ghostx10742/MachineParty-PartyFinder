extends Node

# =============================================================================
#  Machine Party Server Browser - core singleton
# -----------------------------------------------------------------------------
#  Adds a global, non-region-locked public lobby browser on top of the game's
#  existing Steam networking, WITHOUT changing how the base game works.
#
#  The base game (SteamBackend) always creates lobbies as LOBBY_TYPE_FRIENDS_ONLY
#  with a fixed data key "name"="GZytNjrpQh", so they never appear in a public
#  worldwide search. This mod lets the host flip an already-created lobby to
#  LOBBY_TYPE_PUBLIC and stamps our own metadata keys so the browser can find and
#  describe it. Turning it private again restores FRIENDS_ONLY. Joining reuses the
#  game's own client flow (GameManager.join_lobby_id -> lobby_scene).
#
#  This node is added at startup by mod_main.gd and lives under /root. Reference
#  it from anywhere with:  ServerBrowserCore.instance
# =============================================================================

# Access without relying on class_name registration inside a runtime mod.
# Untyped so callers can invoke this script's own methods on it without the
# static analyzer restricting them to the base Node interface.
static var instance = null

# --- Steam lobby-data keys owned by this mod (short to stay well under limits) --
const KEY_MARKER: String = "mpsb"        # "1" => this is a mod-public lobby
const KEY_NAME: String = "mpsb_name"     # user-chosen lobby name
const KEY_MAX: String = "mpsb_max"       # host-chosen max players (1..4)
const KEY_VER: String = "mpsb_ver"       # game_version, so we only list compatible lobbies
const KEY_HOST: String = "mpsb_host"     # host persona name (for display)

const MARKER_ON: String = "1"
const MARKER_OFF: String = "0"

const MAX_PLAYERS_CAP: int = 4           # hard cap requested by design
const MIN_PLAYERS: int = 1

const LOBBY_SCENE_PATH: String = "res://scenes/lobby/lobby_scene.tscn"

# Emitted after a browser refresh completes, with an Array of lobby info dicts:
#   { id:int, name:String, players:int, max:int, version:String, host:String,
#     joinable:bool, compatible:bool }
signal lobbies_refreshed(lobbies)
# Emitted when the host toggles public/private.
signal publish_state_changed(is_public)

var _browsing: bool = false
var _pending_refresh: bool = false


func _ready() -> void:
	instance = self
	# GodotSteam callbacks are pumped globally by the game's Steamworks autoload
	# (Steam.run_callbacks() every frame while initialized), so we only listen.
	if not Steam.lobby_match_list.is_connected(_on_lobby_match_list):
		Steam.lobby_match_list.connect(_on_lobby_match_list)


# ------------------------------------------------------------------ host side --

# The lobby id of the lobby WE currently host (0/-1 if none / not host).
func get_owned_lobby_id() -> int:
	if not NetworkManager.active_backend:
		return 0
	var id: int = NetworkManager.active_backend.lobby_id
	if id <= 0:
		return 0
	# must actually be the server/host to change lobby data
	if not (multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server()):
		return 0
	return id


func is_owned_lobby_public() -> bool:
	var id := get_owned_lobby_id()
	if id <= 0:
		return false
	return Steam.getLobbyData(id, KEY_MARKER) == MARKER_ON


# Make the current hosted lobby appear in the public browser.
func publish(lobby_name: String, max_players: int) -> bool:
	var id := get_owned_lobby_id()
	if id <= 0:
		return false

	max_players = clampi(max_players, MIN_PLAYERS, MAX_PLAYERS_CAP)
	lobby_name = _sanitize_name(lobby_name)

	Steam.setLobbyType(id, Steam.LobbyType.LOBBY_TYPE_PUBLIC)
	Steam.setLobbyJoinable(id, true)
	Steam.setLobbyMemberLimit(id, max_players)

	Steam.setLobbyData(id, KEY_MARKER, MARKER_ON)
	Steam.setLobbyData(id, KEY_NAME, lobby_name)
	Steam.setLobbyData(id, KEY_MAX, str(max_players))
	Steam.setLobbyData(id, KEY_VER, Globals.game_version)
	Steam.setLobbyData(id, KEY_HOST, Steam.getFriendPersonaName(Steam.getSteamID()))

	# keep NetworkManager's own cap in sync so its join gate matches our limit
	NetworkManager.max_player_count = max_players

	publish_state_changed.emit(true)
	return true


# Return the current hosted lobby to the base game's default (friends-only).
func unpublish() -> bool:
	var id := get_owned_lobby_id()
	if id <= 0:
		return false

	Steam.setLobbyType(id, Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY)
	Steam.setLobbyData(id, KEY_MARKER, MARKER_OFF)

	publish_state_changed.emit(false)
	return true


# Change the max-player limit of the current hosted lobby (clamped 1..4).
func set_owned_max_players(max_players: int) -> void:
	var id := get_owned_lobby_id()
	if id <= 0:
		return
	max_players = clampi(max_players, MIN_PLAYERS, MAX_PLAYERS_CAP)
	Steam.setLobbyMemberLimit(id, max_players)
	Steam.setLobbyData(id, KEY_MAX, str(max_players))
	NetworkManager.max_player_count = max_players


func _sanitize_name(lobby_name: String) -> String:
	lobby_name = lobby_name.strip_edges()
	if lobby_name.is_empty():
		lobby_name = "%s's lobby" % Steam.getFriendPersonaName(Steam.getSteamID())
	# Steam lobby-data values are limited; keep it short.
	return lobby_name.substr(0, 63)


# ---------------------------------------------------------------- browse side --

func start_browsing() -> void:
	_browsing = true
	refresh_lobbies()


func stop_browsing() -> void:
	_browsing = false


# Request a fresh worldwide list of mod-public lobbies.
func refresh_lobbies() -> void:
	if not Steamworks.is_initialized:
		lobbies_refreshed.emit([])
		return
	_pending_refresh = true
	# Global, not region-locked.
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	# Only lobbies that opted into the browser.
	Steam.addRequestLobbyListStringFilter(KEY_MARKER, MARKER_ON, Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
	# Ask Steam for a generous result count.
	Steam.addRequestLobbyListResultCountFilter(50)
	Steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	if not _pending_refresh:
		return
	_pending_refresh = false

	var results: Array = []
	for lobby_id in lobbies:
		var id: int = int(lobby_id)
		if Steam.getLobbyData(id, KEY_MARKER) != MARKER_ON:
			continue

		var lname: String = Steam.getLobbyData(id, KEY_NAME)
		if lname.strip_edges().is_empty():
			lname = Steam.getLobbyData(id, KEY_HOST)
		if lname.strip_edges().is_empty():
			lname = "Machine Party Lobby"

		var version: String = Steam.getLobbyData(id, KEY_VER)

		var max_players: int = int(Steam.getLobbyData(id, KEY_MAX))
		if max_players <= 0:
			max_players = Steam.getLobbyMemberLimit(id)
		if max_players <= 0:
			max_players = MAX_PLAYERS_CAP

		var players: int = Steam.getNumLobbyMembers(id)
		if players <= 0:
			players = 1

		results.append({
			"id": id,
			"name": lname,
			"players": players,
			"max": max_players,
			"version": version,
			"host": Steam.getLobbyData(id, KEY_HOST),
			"joinable": players < max_players,
			"compatible": version == Globals.game_version or version.is_empty(),
		})

	# Full/incompatible lobbies sink to the bottom; then most players first.
	results.sort_custom(func(a, b):
		if a["compatible"] != b["compatible"]:
			return a["compatible"]
		if a["joinable"] != b["joinable"]:
			return a["joinable"]
		return a["players"] > b["players"]
	)

	lobbies_refreshed.emit(results)


# ------------------------------------------------------------------ join side --

# Join a public lobby found in the browser. Mirrors GameManager._on_steam_join_requested
# so the base client flow (lobby_scene -> NetworkManager.start_client) runs unchanged.
func join_lobby(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	GameManager.join_lobby_id = lobby_id
	GameManager.host_game = false
	GameManager.custom_game = false

	if MusicManager and MusicManager.filter_controller:
		MusicManager.filter_controller.begin_shift(
			MusicManager.filter_controller.effect_low_pass.cutoff_hz, 300, 4, 1
		)
	GlobalOverlay.fade_overlay(Color.BLACK, 1.0)
	await GlobalOverlay.fade_finished
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


# Join a private lobby by its 18-digit room-ID code (same format the base game uses).
# Returns "" on success, or an error message key/string to show the user.
func join_by_code(code: String) -> String:
	code = code.strip_edges()
	if code.length() != 18 or not code.is_valid_int():
		return "LOC_TAG_NO_ROOM_ID"
	join_lobby(int(code))
	return ""
