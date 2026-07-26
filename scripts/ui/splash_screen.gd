extends Control

signal splash_dismissed

const HERO_COLOR := Color("#ff8c42")
const BG_COLOR := Color("#07080d")
const COUSIN_COLORS: Array[Color] = [
	Color("#ff8c42"), Color("#ff4f42"), Color("#6fd8ff"),
	Color("#b06fff"), Color("#3fd8b0"), Color("#ffd84a")
]
const COUSIN_NAMES: Array[String] = [
	"Blingo", "Blazo", "Blizzy", "Blomba", "Bloopy", "Blondie"
]

var _stars_rect: ColorRect
var _stars: Array[Dictionary] = []
var _t: float = 0.0
var _shown: int = 0
var _cycle_t: float = 0.0
var _dismissed: bool = false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)
	
	# Stars canvas
	_stars_rect = ColorRect.new()
	_stars_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stars_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stars_rect)
	_stars_rect.draw.connect(_draw_stars)
	
	# Generate stars
	for _i in range(240):
		_stars.append({
			"a": randf() * TAU,
			"d": randf() * 0.04,
			"sp": 0.25 + randf() * 0.6
		})
	
	# Cousin name label
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.add_theme_font_size_override("font_size", 52)
	name_label.add_theme_color_override("font_color", COUSIN_COLORS[0])
	name_label.text = COUSIN_NAMES[0]
	add_child(name_label)
	
	# Hint label
	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_bottom = 1.0
	hint.offset_bottom = -40
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.text = "CLICK OR PRESS ANY KEY"
	add_child(hint)


func _draw_stars() -> void:
	var cx: float = _stars_rect.size.x / 2.0
	var cy: float = _stars_rect.size.y / 2.0
	var max_r: float = sqrt(cx * cx + cy * cy)
	for star: Dictionary in _stars:
		var r: float = star["d"] * _t * 0.4
		while r > max_r:
			r -= max_r
		var sx: float = cx + cos(star["a"]) * r
		var sy: float = cy + sin(star["a"]) * r * 0.5
		var br: float = clampf(1.0 - r / max_r, 0.0, 0.9)
		_stars_rect.draw_circle(Vector2(sx, sy), star["sp"], Color.WHITE, false, br)


func _process(delta: float) -> void:
	if _dismissed:
		return
	_t += delta
	_cycle_t += delta
	
	# Cycle cousin every 3.25 seconds
	if _cycle_t > 3.25:
		_cycle_t = 0.0
		_shown = (_shown + 1) % 6
		var name_label: Label = $NameLabel
		name_label.add_theme_color_override("font_color", COUSIN_COLORS[_shown])
		name_label.text = COUSIN_NAMES[_shown]
	
	_stars_rect.queue_redraw()


func _input(event: InputEvent) -> void:
	if _dismissed:
		return
	if event is InputEventMouseButton or event is InputEventKey:
		_dismissed = true
		SignalBus.splash_dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	_input(event)
