extends RefCounted

# =============================================================================
#  Native UI helpers - loads Machine Party's own Theme + fonts so every control
#  this mod creates looks identical to the base game's menus.
# =============================================================================

const THEME_MAIN_MENU: String = "res://themes/main_menu_theme.tres"
const THEME_LOBBY: String = "res://themes/lobby_theme.tres"
const THEME_PAUSE: String = "res://themes/pause_menu_theme.tres"

# Fonts shipped with the game (used by its menus).
const FONT_WHITRABT: String = "res://fonts/whitrabt.ttf"
const FONT_TERMINAL: String = "res://fonts/Terminal F4.ttf"
const FONT_HACK: String = "res://fonts/Hack-Regular.ttf"

static var _theme_cache: Dictionary = {}
static var _font_cache: Dictionary = {}


static func _load_theme(path: String) -> Theme:
	if _theme_cache.has(path):
		return _theme_cache[path]
	var t: Theme = null
	if ResourceLoader.exists(path):
		t = load(path) as Theme
	_theme_cache[path] = t
	return t


static func menu_theme() -> Theme:
	return _load_theme(THEME_MAIN_MENU)


static func lobby_theme() -> Theme:
	return _load_theme(THEME_LOBBY)


static func font(path: String = FONT_WHITRABT) -> Font:
	if _font_cache.has(path):
		return _font_cache[path]
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path) as Font
	_font_cache[path] = f
	return f


# Apply the game's menu theme to a control subtree so children inherit native
# styleboxes / fonts / colors.
static func apply_menu_theme(control: Control) -> void:
	var t := menu_theme()
	if t:
		control.theme = t


# ---- factory helpers (all inherit the ancestor Control.theme) ----------------

static func make_label(text: String, font_size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	var f := font()
	if f:
		l.add_theme_font_override("font", f)
	return l


static func make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	var f := font()
	if f:
		b.add_theme_font_override("font", f)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


# A system font that reliably contains symbol glyphs (arrows, close X) which the
# game's whitrabt font may lack. Prevents tofu boxes on symbol buttons.
static var _symbol_font: Font = null
static func symbol_font() -> Font:
	if _symbol_font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([
			"Segoe UI Symbol", "Segoe UI", "Arial Unicode MS", "DejaVu Sans", "Noto Sans Symbols"
		])
		_symbol_font = sf
	return _symbol_font


static func make_symbol_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", symbol_font())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func make_line_edit(placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	var f := font()
	if f:
		e.add_theme_font_override("font", f)
	return e


static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	return p
