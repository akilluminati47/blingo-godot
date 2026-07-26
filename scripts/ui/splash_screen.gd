extends Control

# Splash screen — starfield with hero-tinted space, cousin blob cycling
# Mirrors the opening splash from the original BLINGO HTML5 game
# Press anywhere / any key to dismiss and unlock audio

const HERO_COLOR = Color("#ff8c42")
const BG_COLOR = Color("#07080d")

# Cousin data — mirrors COUSINS array from original game.js
const COUSINS = [
	{ "id": "blingo",  "name": "Blingo",  "color": Color("#ff8c42"), "perk": "Balanced hero", "lore": "The First Immune. Bitten at the Blob Falls picnic on day one, never turned. He swore on his grandma's jelly recipe to take the town back." },
	{ "id": "blazo",   "name": "Blazo",   "color": Color("#ff4f42"), "perk": "+15% damage",   "lore": "Blingo's hot-headed cousin. The horde ate his championship chili stand. Now every trigger pull is seasoned with revenge." },
	{ "id": "blizzy",  "name": "Blizzy",  "color": Color("#6fd8ff"), "perk": "+12% sprint speed", "lore": "The coolest head of the six. Scouted the frozen north alone for two winters. Zombies can't catch what they can't chill." },
	{ "id": "blomba",  "name": "Blomba",  "color": Color("#b06fff"), "perk": "+25 max HP",    "lore": "Big-hearted bouncer of the old Blob Lounge. Soft on the inside, softer on the outside, absolutely will not fall over." },
	{ "id": "bloopy",  "name": "Bloopy",  "color": Color("#3fd8b0"), "perk": "35% faster reload", "lore": "Fidgety tinkerer who rebuilt the family radio from soup cans. Hands so twitchy the reloads finish themselves." },
	{ "id": "blondie", "name": "Blondie", "color": Color("#ffd84a"), "perk": "+50% ammo from loot", "lore": "The family hoarder. Her pockets don't make sense geometrically. If there's a bullet in a crate, she'll find three." },
]

var _stars: Array = []
var _shown_cousin: int = 0
var _morph: int = 0          # 0=stable, 1=blurring out, 2=blurring in
var _morph_t: float = 0.0
var _t: float = 0.0
var _hero_bg := BG_COLOR
var _hint_label: Label
var _name_label: Label
var _chevron_label: Label
var _face_rect: ColorRect
var _stars_rect: ColorRect
var _is_ready := false
var _dismissed := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_setup_stars()
	_setup_blob_display()
	_setup_tag()
	_setup_hint()
	_is_ready = true
	_show_cousin(0)
	$StarsRect.position = Vector2.ZERO
	$StarsRect.size = get_viewport_rect().size
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func _setup_stars() -> void:
	_stars_rect = ColorRect.new()
	_stars_rect.name = "StarsRect"
	_stars_rect.mouse_filter = MOUSE_FILTER_IGNORE
	_stars_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stars_rect)
	_stars_rect.draw.connect(_draw_stars)
	for _i in range(240):
		_stars.append({
			"a": randf() * TAU,
			"d": randf() * 0.04,
			"sp": 0.25 + randf() * 0.6
		})

func _setup_blob_display() -> void:
	_face_rect = ColorRect.new()
	_face_rect.name = "BlobFace"
	_face_rect.mouse_filter = MOUSE_FILTER_IGNORE
	_face_rect.custom_minimum_size = Vector2(120, 120)
	add_child(_face_rect)
	_face_rect.draw.connect(_draw_blob_face)

func _setup_tag() -> void:
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 52)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_chevron_label = Label.new()
	_chevron_label.name = "ChevronLabel"
	_chevron_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chevron_label.text = "▼"
	_chevron_label.add_theme_font_size_override("font_size", 38)
	_chevron_label.add_theme_color_override("font_color", Color.WHITE)
	_chevron_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_chevron_label)

func _setup_hint() -> void:
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = "LOADING . ."
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_hint_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_hint_label)

func mark_ready() -> void:
	_hint_label.text = "CLICK / ANY KEY / ANY BUTTON .ᐟ"

func _on_resize() -> void:
	var vs := get_viewport_rect().size
	_stars_rect.size = vs
	# Position blob face: centered horizontally, ~35% from top
	_face_rect.position = Vector2((vs.x - 120) / 2.0, vs.y * 0.35 - 60)
	# Tag above the blob
	_name_label.position = Vector2((vs.x - 350) / 2.0, _face_rect.position.y - 80)
	_name_label.size = Vector2(350, 68)
	_chevron_label.position = Vector2((vs.x - 100) / 2.0, _name_label.position.y + 58)
	_chevron_label.size = Vector2(100, 48)
	# Hint at bottom
	_hint_label.position = Vector2((vs.x - 400) / 2.0, vs.y - 90)
	_hint_label.size = Vector2(400, 36)

func _process(dt: float) -> void:
	if not _is_ready or _dismissed:
		return
	_t += dt

	# --- Starfield: rush outward from center with varying speeds ---
	_stars_rect.queue_redraw()

	# --- Hero-tinted background ---
	var hero := COUSINS[_shown_cousin]
	var target_bg := hero.color
	target_bg = target_bg * Color(0.13, 0.13, 0.13)
	_hero_bg = _hero_bg.lerp(target_bg, 1.0 - exp(-2.2 * dt))

	# --- Cousin morph cycling ---
	var tab_cousin := wrapi(int(floor(_t / 3.25)) % COUSINS.size(), 0, COUSINS.size())
	if _morph == 0 and tab_cousin != _shown_cousin:
		_start_morph()
	elif _morph == 1:
		_morph_t += dt
		if _morph_t >= 0.42:
			_complete_morph(tab_cousin)
	elif _morph == 2:
		_morph_t += dt
		if _morph_t >= 0.42:
			_morph = 0

	# --- Blob face "rotation" — gentle scale pulse ---
	var pulse := 1.0 + sin(_t * 0.45) * 0.04
	_face_rect.scale = Vector2(pulse, pulse)
	_face_rect.queue_redraw()

func _start_morph() -> void:
	_morph = 1
	_morph_t = 0.0

func _complete_morph(new_cousin: int) -> void:
	_shown_cousin = new_cousin
	_show_cousin(new_cousin)
	_morph = 2
	_morph_t = 0.0

func _show_cousin(idx: int) -> void:
	var c := COUSINS[idx]
	_name_label.text = c.name.to_upper()
	_name_label.add_theme_color_override("font_color", c.color)
	_chevron_label.add_theme_color_override("font_color", c.color)

# --- Star drawing on the stars ColorRect ---
func _draw_stars() -> void:
	var vs := _stars_rect.size
	var cx := vs.x / 2.0
	var cy := vs.y / 2.0
	var r := hypot(vs.x, vs.y) * 0.52

	var stars: Array = _stars
	for s_dict in stars:
		var d0: float = s_dict["d"]
		s_dict["d"] += s_dict["sp"] * get_process_delta_time() * (0.22 + d0 * 1.6)
		if s_dict["d"] >= 1.0:
			s_dict["a"] = randf() * TAU
			s_dict["d"] = 0.03 + randf() * 0.05
			s_dict["sp"] = 0.25 + randf() * 0.6
			continue

		var e0 := d0 * d0 * r
		var e1 := s_dict["d"] * s_dict["d"] * r
		var a_val: float = s_dict["a"]
		var x0 := cx + cos(a_val) * e0
		var y0 := cy + sin(a_val) * e0
		var x1 := cx + cos(a_val) * e1
		var y1 := cy + sin(a_val) * e1
		var alpha := clampf(0.16 + s_dict["d"] * 0.6, 0.0, 1.0)
		var lw := 0.6 + s_dict["d"] * 1.8

		_stars_rect.draw_line(Vector2(x0, y0), Vector2(x1, y1),
			Color(1.0, 1.0, 1.0, alpha), lw, true)

# --- Procedural blob face drawing ---
func _draw_blob_face() -> void:
	var c := COUSINS[_shown_cousin]
	var color := c.color
	var blur_amt := 0.0
	if _morph == 1:
		blur_amt = clampf(_morph_t / 0.42, 0.0, 1.0)
	elif _morph == 2:
		blur_amt = clampf(1.0 - _morph_t / 0.42, 0.0, 1.0)

	# Draw at 120x120 (same as the rect size)
	var face_scale := 1.875  # 120 / 64
	var base_transform := Transform2D(0.0, Vector2(face_scale, face_scale), 0.0, Vector2.ZERO)

	# Rounded blob head shape — fill in body color
	var head_rect := Rect2(8, 6, 48, 52)
	var corners := PackedVector2Array([
		Vector2(24, 24),  # tl
		Vector2(24, 24),  # tr
		Vector2(20, 20),  # br
		Vector2(20, 20),  # bl
	])

	# Main blob head
	_draw_rounded_rect_scaled(head_rect, corners, color, base_transform)

	# Soft chin shading
	var chin_rect := Rect2(8, 42, 48, 16)
	var chin_corners := PackedVector2Array([
		Vector2.ZERO, Vector2.ZERO,
		Vector2(20, 20), Vector2(20, 20),
	])
	_draw_rounded_rect_scaled(chin_rect, chin_corners, Color(0, 0, 0, 0.14), base_transform)

	# Two googly eyes — Blondie looks left, rest look right
	var gaze_x: float = -1.5 if c.id == "blondie" else 1.5
	for ex in [24.0, 40.0]:
		# White of eye
		var eye_rect := Rect2(ex - 7, 19, 14, 16)
		var eye_corners := PackedVector2Array([
			Vector2(7, 7), Vector2(7, 7), Vector2(7, 7), Vector2(7, 7),
		])
		_draw_rounded_rect_scaled(eye_rect, eye_corners, Color.WHITE, base_transform)

		# Pupil
		var pupil_x := ex + gaze_x
		var pupil_rect := Rect2(pupil_x - 3.2, 26, 6.4, 6.4)
		var pupil_corners := PackedVector2Array([
			Vector2(3.2, 3.2), Vector2(3.2, 3.2), Vector2(3.2, 3.2), Vector2(3.2, 3.2),
		])
		_draw_rounded_rect_scaled(pupil_rect, pupil_corners, Color("#222222"), base_transform)

func _draw_rounded_rect_scaled(rect: Rect2, corners: PackedVector2Array, color: Color, xf: Transform2D) -> void:
	var r := rect
	# Build path manually for rounded rect
	var tl := corners[0].x
	var tr := corners[1].x
	var br := corners[2].x
	var bl := corners[3].x

	var pts := PackedVector2Array()
	pts.append(Vector2(r.position.x + tl, r.position.y))
	pts.append(Vector2(r.position.x + r.size.x - tr, r.position.y))
	# Top edge done; now top-right curve
	var steps := 6
	for i in range(1, steps + 1):
		var angle := -PI / 2.0 + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + r.size.x - tr + cos(angle) * tr, r.position.y + tr - sin(angle) * tr))
	pts.append(Vector2(r.position.x + r.size.x, r.position.y + tr))

	pts.append(Vector2(r.position.x + r.size.x, r.position.y + r.size.y - br))
	# Bottom-right curve
	for i in range(1, steps + 1):
		var angle := 0.0 + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + r.size.x - br + cos(angle) * br, r.position.y + r.size.y - br + sin(angle) * br))
	pts.append(Vector2(r.position.x + r.size.x - br, r.position.y + r.size.y))

	pts.append(Vector2(r.position.x + bl, r.position.y + r.size.y))
	# Bottom-left curve
	for i in range(1, steps + 1):
		var angle := PI / 2.0 + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + bl + cos(angle) * bl, r.position.y + r.size.y - bl + sin(angle) * bl))
	pts.append(Vector2(r.position.x, r.position.y + r.size.y - bl))

	pts.append(Vector2(r.position.x, r.position.y + tl))
	# Top-left curve
	for i in range(1, steps + 1):
		var angle := PI + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + tl + cos(angle) * tl, r.position.y + tl + sin(angle) * tl))

	# Transform & draw
	for i in range(pts.size()):
		pts[i] = xf * pts[i]

	draw_colored_polygon(pts, color)

# --- Input handling ---
func _input(event: InputEvent) -> void:
	if _dismissed:
		return
	if event is InputEventMouseButton and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if _dismissed:
		return
	if event is InputEventMouseButton and event.pressed:
		_dismiss()

func _dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true

	# Signal that the splash is being dismissed
	SignalBus.splash_dismissed.emit()

	# Fade out animation
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
