extends Node

# =============================================================================
#  Party Finder - Machine Party server browser - mod entry point (GodotModding ModLoader 7.x)
# -----------------------------------------------------------------------------
#  * Adds a server browser singleton node (Steam publish/browse/join logic).
#  * Hooks MainMenu.set_button_signals -> repurpose the JOIN button to open the
#    server browser overlay.
#  * Hooks lobby_scene._on_server_created -> inject the "Make Lobby Public"
#    toggle into the host's lobby screen.
#
#  Hooks (not script extensions) are used because the game's MainMenu declares
#  `class_name MainMenu`, and ModLoader cannot script-extend class_name scripts.
# =============================================================================

const MOD_ID := "Jaxon-PartyFinder"
const LOG_NAME := "Jaxon-PartyFinder:Main"

const CORE := preload("res://mods-unpacked/Jaxon-PartyFinder/server_browser.gd")
const BrowserScreen := preload("res://mods-unpacked/Jaxon-PartyFinder/ui/server_browser_screen.gd")
const MakePublicController := preload("res://mods-unpacked/Jaxon-PartyFinder/ui/make_public_controller.gd")

const MAIN_MENU_SCRIPT := "res://scenes/main_menu/scripts/main_menu.gd"
const LOBBY_SCENE_SCRIPT := "res://scenes/lobby/scripts/lobby_scene.gd"


func _init() -> void:
	ModLoaderMod.add_hook(_hook_main_menu_buttons, MAIN_MENU_SCRIPT, "set_button_signals")
	ModLoaderMod.add_hook(_hook_lobby_server_created, LOBBY_SCENE_SCRIPT, "_on_server_created")


func _ready() -> void:
	# Add the core singleton as a child of this mod node (/root/ModLoader/Jaxon-PartyFinder/...).
	if not has_node("MPSB_ServerBrowser"):
		var core: Node = CORE.new()
		core.name = "MPSB_ServerBrowser"
		add_child(core)
	ModLoaderLog.info("Party Finder ready.", LOG_NAME)


# ---- Hook: repurpose the main-menu JOIN button --------------------------------

func _hook_main_menu_buttons(chain: ModLoaderHookChain) -> void:
	chain.execute_next()           # let the game wire all its buttons first
	var menu = chain.reference_object
	if not is_instance_valid(menu) or not is_instance_valid(menu.start_join_button):
		return
	# Drop the base game's clipboard-join handler(s), take over the button.
	for conn in menu.start_join_button.pressed.get_connections():
		menu.start_join_button.pressed.disconnect(conn["callable"])
	menu.start_join_button.pressed.connect(func(): _open_browser(menu))


func _open_browser(menu) -> void:
	if not Steamworks.is_initialized:
		if is_instance_valid(menu):
			menu.set_tooltip(tr("LOC_TAG_STEAM_FAIL"), Color.CRIMSON)
		return
	if get_tree().root.has_node("MPSB_ServerBrowserScreen"):
		return
	var browser: CanvasLayer = BrowserScreen.new()
	browser.name = "MPSB_ServerBrowserScreen"
	get_tree().root.add_child(browser)


# ---- Hook: inject "Make Lobby Public" toggle for the host ---------------------

func _hook_lobby_server_created(chain: ModLoaderHookChain) -> void:
	chain.execute_next()
	var lobby = chain.reference_object
	if not is_instance_valid(lobby):
		return
	_inject_public_toggle(lobby)


func _inject_public_toggle(lobby) -> void:
	if not (multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server()):
		return
	var handler = lobby.lobby_handler
	if not is_instance_valid(handler):
		return
	# Use a real native lobby button as the template so the toggle matches the
	# game's exact font / size / color / stylebox.
	var template: Button = handler.copy_lobby_id_button
	if not is_instance_valid(template):
		template = handler.invite_button
	if not is_instance_valid(template):
		return
	var parent := template.get_parent()
	if not is_instance_valid(parent) or parent.has_node("MPSB_MakePublicToggle"):
		return

	var toggle: Button = template.duplicate()
	toggle.name = "MPSB_MakePublicToggle"
	toggle.visible = true
	toggle.disabled = false
	# Strip any signal connections carried over from the template button.
	for conn in toggle.pressed.get_connections():
		toggle.pressed.disconnect(conn["callable"])
	parent.add_child(toggle)
	parent.move_child(toggle, template.get_index() + 1)

	# Controller node drives the toggle (its parent) and lives/dies with it.
	var controller := MakePublicController.new()
	controller.name = "MPSB_Controller"
	toggle.add_child(controller)
