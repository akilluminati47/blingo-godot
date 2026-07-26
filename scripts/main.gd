extends Node

func _ready() -> void:
	print("BLINGO - Godot 4.7")
	
	# Simple test: red background Control
	var ctrl := Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.ORANGE
	ctrl.add_child(bg)
	
	var label := Label.new()
	label.text = "BLINGO"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color.WHITE)
	ctrl.add_child(label)
	
	add_child(ctrl)
	print("UI set up — you should see orange screen with BLINGO text")
