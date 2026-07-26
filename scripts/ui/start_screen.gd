extends Control

# Start / Menu screen for BLINGO
# - BLINGO title (the I is hero-tinted)
# - Typewriter town lore text cycling (gold + white lines)
# - Prestige badge strip
# - Six cousin cards (click to select, preview persona theme)
# - SINGLE PLAYER / MULTIPLAYER mode buttons
# - "Cousin Themes · Terms & Privacy" footer link

const HERO_COLOR = Color("#ff8c42")
const GOLD_COLOR = Color("#ffd9a8")
const WHITE_COLOR = Color("#eef1f5")
const DIM_COLOR = Color("#5a5a64")
const CARD_BG = Color(1, 1, 1, 0.06)
const CARD_BORDER = Color(1, 1, 1, 0.14)
const CARD_SELECTED_BORDER = Color.WHITE
const CARD_SELECTED_BG = Color(1, 1, 1, 0.14)

const COUSINS = [
	{ "id": "blingo",  "name": "Blingo",  "color": Color("#ff8c42"), "perk": "Balanced hero", "lore": "The First Immune. Bitten at the Blob Falls picnic on day one, never turned." },
	{ "id": "blazo",   "name": "Blazo",   "color": Color("#ff4f42"), "perk": "+15% damage",   "lore": "Blingo's hot-headed cousin. The horde ate his championship chili stand." },
	{ "id": "blizzy",  "name": "Blizzy",  "color": Color("#6fd8ff"), "perk": "+12% sprint speed", "lore": "The coolest head of the six. Scouted the frozen north alone for two winters." },
	{ "id": "blomba",  "name": "Blomba",  "color": Color("#b06fff"), "perk": "+25 max HP",    "lore": "Big-hearted bouncer of the old Blob Lounge. Soft on the inside, softer on the outside." },
	{ "id": "bloopy",  "name": "Bloopy",  "color": Color("#3fd8b0"), "perk": "35% faster reload", "lore": "Fidgety tinkerer who rebuilt the family radio from soup cans." },
	{ "id": "blondie", "name": "Blondie", "color": Color("#ffd84a"), "perk": "+50% ammo from loot", "lore": "The family hoarder. Her pockets don't make sense geometrically." },
]

const GOLD_LINES = [
	"When the horde came, every blob turned . . except six cousins.",
	"The bites never took.",
	"Now the immune cousins are clearing the wasteland block by block, so the rest of blob-kind can finally move back home .ᐟ",
]
const WHITE_LINES = [
	"Pick your cousin.",
	"The other five are out there somewhere, find them, recruit them, fight together.",
	"Loot the glowing crates for guns & ammo.",
]
const LUCK_LINE = "Good Luck .ᐟ"

const TYPE_SPEED_MS := 32
const WIPE_SPEED_MS := 4
const HOLD_TIME_MS := 4200
const BLANK_TIME_MS := 900

# -- State --
var _selected_cousin: int = 0
var _typewriter_state: int = 0   # 0=idle, 1=filling gold, 2=filling white, 3=holding luck, 4=wiping white, 5=wiping gold, 6=pause
var _typewriter_char: int = 0
var _typewriter_timer: float = 0.0
var _gold_text: String
var _white_text: String
var _full_white: String
var _tag_target: Color = HERO_COLOR

# -- Node refs --
var _content_vbox: VBoxContainer
var _title_label: Label
var _type_gold: Label
var _type_white: Label
var _prestige_container: HBoxContainer
var _cards_container: GridContainer
var _card_controls: Array = []
var _mode_container: HBoxContainer
var _footer_label: RichTextLabel
var _play_btn: Button
var _mp_btn: Button

func _ready() -> void:
	_content_vbox = $ScrollContainer/ContentVBox as VBoxContainer
	_setup_title()
	_setup_typewriter()
	_setup_prestige()
	_setup_cards()
	_setup_mode_buttons()
	_setup_footer()
	_reset_typewriter()
	set_process(true)

func _setup_title() -> void:
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "BLINGO"
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(_title_label)
	# The "I" is tinted hero color — use BBCode
	_update_title_tag()

func _update_title_tag() -> void:
	var hex := _tag_target.to_html(false)
	_title_label.text = "[center]BL" + (
		"[color=" + hex + "]I[/color]NGO[/center]")

func _setup_typewriter() -> void:
	_gold_text = "\n".join(GOLD_LINES)
	_white_text = "\n".join(WHITE_LINES)
	_full_white = _white_text + "\n" + LUCK_LINE

	_type_gold = Label.new()
	_type_gold.name = "TypeGold"
	_type_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_gold.add_theme_font_size_override("font_size", 16)
	_type_gold.add_theme_color_override("font_color", DIM_COLOR)
	_type_gold.autowrap_mode = TextServer.AUTOWRAP_WORD
	_type_gold.custom_minimum_size = Vector2(480, 80)
	_type_gold.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(_type_gold)

	_type_white = Label.new()
	_type_white.name = "TypeWhite"
	_type_white.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_white.add_theme_font_size_override("font_size", 16)
	_type_white.add_theme_color_override("font_color", DIM_COLOR)
	_type_white.autowrap_mode = TextServer.AUTOWRAP_WORD
	_type_white.custom_minimum_size = Vector2(480, 80)
	_type_white.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(_type_white)

func _setup_prestige() -> void:
	_prestige_container = HBoxContainer.new()
	_prestige_container.name = "PrestigeContainer"
	_prestige_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_prestige_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(_prestige_container)
	# Prestige badges will be populated by GameState when available
	_refresh_prestige()

func _refresh_prestige() -> void:
	for child in _prestige_container.get_children():
		child.queue_free()

	var gs := GameState as Node

	# Best streak badge
	var best_streak: int = gs.best_streak
	if best_streak > 0:
		var b := _make_badge("BLOCKS SECURED x" + str(best_streak), Color.WHITE)
		_prestige_container.add_child(b)

	# Best time badge
	var best_time: float = gs.best_time
	if best_time > 0.0:
		var mins := int(best_time / 60.0)
		var secs := int(fmod(best_time, 60.0))
		var time_str := str(mins) + ":" + ("%02d" % secs)
		var badge_color: Color = gs.best_hero_color
		var b := _make_badge("FASTEST " + time_str, badge_color)
		_prestige_container.add_child(b)

func _make_badge(text: String, bc: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.border_color = bc
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", bc)
	panel.add_child(lbl)
	return panel

func _setup_cards() -> void:
	_cards_container = GridContainer.new()
	_cards_container.name = "CousinCards"
	_cards_container.columns = 3
	_cards_container.add_theme_constant_override("h_separation", 10)
	_cards_container.add_theme_constant_override("v_separation", 10)
	_cards_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cards_container.custom_minimum_size = Vector2(530, 0)
	_content_vbox.add_child(_cards_container)

	for i in COUSINS.size():
		var card := _make_cousin_card(i)
		_cards_container.add_child(card)
		_card_controls.append(card)

	_update_card_selection()

func _make_cousin_card(idx: int) -> Control:
	var c := COUSINS[idx]
	var outer := MarginContainer.new()
	outer.name = "Card_" + c.id
	outer.custom_minimum_size = Vector2(160, 140)
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var vbox := VBoxContainer.new()
	vbox.name = "CardVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Blob face (drawn canvas-style)
	var face := Control.new()
	face.name = "Face"
	face.custom_minimum_size = Vector2(46, 46)
	face.mouse_filter = MOUSE_FILTER_PASS
	face.draw.connect(_on_card_face_draw.bind(idx, face))
	vbox.add_child(face)

	# Name
	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.text = c.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	# Perk
	var perk_lbl := Label.new()
	perk_lbl.name = "Perk"
	perk_lbl.text = c.perk.to_upper()
	perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_lbl.add_theme_font_size_override("font_size", 9)
	perk_lbl.add_theme_color_override("font_color", Color("#7bd88f"))
	vbox.add_child(perk_lbl)

	# Lore
	var lore_lbl := Label.new()
	lore_lbl.name = "Lore"
	lore_lbl.text = c.lore
	lore_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lore_lbl.add_theme_font_size_override("font_size", 11)
	lore_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	vbox.add_child(lore_lbl)

	outer.add_child(vbox)

	# Background panel
	var panel := PanelContainer.new()
	panel.name = "BorderPanel"
	panel.mouse_filter = MOUSE_FILTER_PASS
	outer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var s := _card_style(idx == _selected_cousin)
	panel.add_theme_stylebox_override("panel", s)

	# Input handling
	var btn := Button.new()
	btn.name = "CardButton"
	btn.flat = true
	btn.mouse_filter = MOUSE_FILTER_PASS
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(_on_card_pressed.bind(idx))
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.call_deferred("move_child", btn, 0)

	return outer

func _card_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CARD_SELECTED_BG if selected else CARD_BG
	s.border_color = CARD_SELECTED_BORDER if selected else CARD_BORDER
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14
	s.corner_radius_bottom_right = 14
	return s

func _on_card_face_draw(idx: int, face_ctrl: Control) -> void:
	var c := COUSINS[idx]
	var size := face_ctrl.size
	var scale_factor := size.x / 64.0
	var xf := Transform2D(0.0, Vector2(scale_factor, scale_factor), 0.0, Vector2.ZERO)

	# Rounded blob head
	_draw_rounded(face_ctrl, Rect2(8, 6, 48, 52), c.color, xf, 24, 24, 20, 20)

	# Chin shading
	_draw_rounded(face_ctrl, Rect2(8, 42, 48, 16),
		Color(0, 0, 0, 0.14), xf, 0, 0, 20, 20)

	# Eyes
	var gaze: float = -1.5 if c.id == "blondie" else 1.5
	for ex in [24.0, 40.0]:
		_draw_rounded(face_ctrl, Rect2(ex - 7, 19, 14, 16),
			Color.WHITE, xf, 7, 7, 7, 7)
		_draw_rounded(face_ctrl, Rect2(ex + gaze - 3.2, 26, 6.4, 6.4),
			Color("#222222"), xf, 3.2, 3.2, 3.2, 3.2)

func _draw_rounded(ctrl: Control, rect: Rect2, color: Color, xf: Transform2D, tl: float, tr: float, br: float, bl: float) -> void:
	var r := rect
	var steps := 6
	var pts := PackedVector2Array()

	pts.append(Vector2(r.position.x + tl, r.position.y))
	pts.append(Vector2(r.position.x + r.size.x - tr, r.position.y))
	for i in range(1, steps + 1):
		var angle := -PI / 2.0 + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + r.size.x - tr + cos(angle) * tr, r.position.y + tr - sin(angle) * tr))
	pts.append(Vector2(r.position.x + r.size.x, r.position.y + tr))

	pts.append(Vector2(r.position.x + r.size.x, r.position.y + r.size.y - br))
	for i in range(1, steps + 1):
		var angle := 0.0 + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + r.size.x - br + cos(angle) * br, r.position.y + r.size.y - br + sin(angle) * br))
	pts.append(Vector2(r.position.x + r.size.x - br, r.position.y + r.size.y))

	pts.append(Vector2(r.position.x + bl, r.position.y + r.size.y))
	for i in range(1, steps + 1):
		var angle := PI / 2.0 + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + bl + cos(angle) * bl, r.position.y + r.size.y - bl + sin(angle) * bl))
	pts.append(Vector2(r.position.x, r.position.y + r.size.y - bl))

	pts.append(Vector2(r.position.x, r.position.y + tl))
	for i in range(1, steps + 1):
		var angle := PI + (PI / 2.0) * (float(i) / float(steps + 1))
		pts.append(Vector2(r.position.x + tl + cos(angle) * tl, r.position.y + tl + sin(angle) * tl))

	for i in range(pts.size()):
		pts[i] = xf * pts[i]

	ctrl.draw_colored_polygon(pts, color)

func _on_card_pressed(idx: int) -> void:
	_selected_cousin = idx
	_tag_target = COUSINS[idx].color
	_update_card_selection()
	_update_title_tag()
	# Update GameState
	GameState.selected_cousin = idx
	# Preview theme — placeholder for theme playback
	SignalBus.cousin_selected.emit(idx)

func _update_card_selection() -> void:
	for i in range(_card_controls.size()):
		var outer: Control = _card_controls[i]
		# Find the BorderPanel child and update its style
		var panel: PanelContainer = null
		for child in outer.get_children():
			if child is PanelContainer:
				panel = child
				break
		if panel:
			panel.add_theme_stylebox_override("panel", _card_style(i == _selected_cousin))

func _setup_mode_buttons() -> void:
	_mode_container = HBoxContainer.new()
	_mode_container.name = "ModeContainer"
	_mode_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_mode_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(_mode_container)

	_play_btn = _make_mode_button("SINGLE PLAYER")
	_mp_btn = _make_mode_button("MULTIPLAYER")
	_mode_container.add_child(_play_btn)
	_mode_container.add_child(_mp_btn)

	_play_btn.pressed.connect(_on_single_player)
	_mp_btn.pressed.connect(_on_multiplayer)

func _make_mode_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", _tag_target)
	btn.add_theme_color_override("font_hover_color", Color("#10131a"))
	btn.custom_minimum_size = Vector2(200, 50)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.039, 0.047, 0.071, 0.6)
	s.border_color = _tag_target
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", s)

	var hover := StyleBoxFlat.new()
	hover.bg_color = _tag_target
	hover.border_color = _tag_target
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", hover)

	return btn

func _on_single_player() -> void:
	SignalBus.single_player_pressed.emit()

func _on_multiplayer() -> void:
	SignalBus.multiplayer_pressed.emit()

func _setup_footer() -> void:
	_footer_label = RichTextLabel.new()
	_footer_label.name = "FooterLink"
	_footer_label.fit_content = true
	_footer_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_footer_label.bbcode_enabled = true
	_footer_label.text = "[center][color=#9aa4b2]Cousin Themes ♪ · Terms & Privacy[/color][/center]"
	_footer_label.meta_clicked.connect(_on_footer_clicked)
	_content_vbox.add_child(_footer_label)

func _on_footer_clicked(_meta: Variant) -> void:
	SignalBus.policies_pressed.emit()

# --- Typewriter system ---
func _reset_typewriter() -> void:
	_typewriter_state = 1
	_typewriter_char = 0
	_typewriter_timer = 0.0
	# Show full text dimmed initially
	_type_gold.text = _gold_text
	_type_white.text = _full_white

func _render(el: Label, text: String, full_text: String, pos: int, color: Color) -> void:
	var out := ""
	for i in range(full_text.length()):
		var ch := full_text[i]
		if ch == "\n":
			out += "\n"
		else:
			if i < pos:
				out += "[color=" + color.to_html(false) + "]" + ch + "[/color]"
			else:
				out += "[color=" + DIM_COLOR.to_html(false) + "]" + ch + "[/color]"
	el.text = out

func _process(dt: float) -> void:
	if not visible:
		return
	_process_typewriter(dt)

func _process_typewriter(dt: float) -> void:
	if _typewriter_state == 0:
		return

	_typewriter_timer += dt * 1000.0

	match _typewriter_state:
		1: # Filling gold text
			var interval := float(TYPE_SPEED_MS)
			if _typewriter_timer >= interval:
				_typewriter_timer -= interval
				_typewriter_char += 1
				if _typewriter_char > _gold_text.length():
					_typewriter_state = 6
					_typewriter_timer = -200.0  # pause after gold fill
					_type_gold.text = _gold_text  # fully revealed
				else:
					_render(_type_gold, _gold_text, _gold_text, _typewriter_char, GOLD_COLOR)
		6: # Short pause — after gold fill → white; after full cycle → restart from gold
			if _typewriter_timer >= 0:
				if _typewriter_char >= 0:
					# Coming from gold fill (char value > gold_text length)
					_typewriter_state = 2
					_typewriter_char = 0
				else:
					# Coming from full cycle wipe (char == -1)
					_reset_typewriter()
				_typewriter_timer = 0.0
		2: # Filling white text
			var interval := float(TYPE_SPEED_MS)
			if _typewriter_timer >= interval:
				_typewriter_timer -= interval
				_typewriter_char += 1
				if _typewriter_char > _white_text.length():
					_typewriter_state = 3
					_typewriter_char = 0
					_typewriter_timer = 0.0
					# Flash the luck line gold
					_flash_luck_line()
				else:
					_render(_type_white, _white_text, _full_white, _typewriter_char, WHITE_COLOR)
		3: # Holding luck line
			if _typewriter_timer >= HOLD_TIME_MS:
				_typewriter_state = 4
				_typewriter_char = _full_white.length() - 1
				_typewriter_timer = 0.0
		4: # Wiping white
			var wipe_int := float(WIPE_SPEED_MS)
			if _typewriter_timer >= wipe_int:
				_typewriter_timer -= wipe_int
				_typewriter_char -= 1
				if _typewriter_char < 0:
					_type_white.text = _full_white  # restored dim
					_typewriter_state = 5
					_typewriter_char = _gold_text.length() - 1
					_typewriter_timer = 0.0
				else:
					_render(_type_white, _full_white, _full_white, _typewriter_char, DIM_COLOR)
		5: # Wiping gold
			var wipe_int := float(WIPE_SPEED_MS)
			if _typewriter_timer >= wipe_int:
				_typewriter_timer -= wipe_int
				_typewriter_char -= 1
				if _typewriter_char < 0:
					_type_gold.text = _gold_text  # restored dim
					_typewriter_state = 6
					_typewriter_timer = -BLANK_TIME_MS
				else:
					_render(_type_gold, _gold_text, _gold_text, _typewriter_char, DIM_COLOR)

func _flash_luck_line() -> void:
	# Set gold span to GOLD_COLOR, white span to WHITE_COLOR, luck line to GOLD_COLOR
	_type_white.text = _white_text + "\n[color=" + GOLD_COLOR.to_html(false) + "]" + LUCK_LINE + "[/color]"

# --- Public API for other systems ---
func set_prestige(best_streak: int, best_time: float, best_hero_color: Color) -> void:
	var gs := GameState as Node
	gs.best_streak = best_streak
	gs.best_time = best_time
	gs.best_hero_color = best_hero_color
	_refresh_prestige()

func show_screen() -> void:
	visible = true
	_reset_typewriter()
	_refresh_prestige()

func hide_screen() -> void:
	visible = false
	_typewriter_state = 0
