class_name InteractionPrompt
extends PanelContainer

const PANEL_COLOR := Color(0.035, 0.055, 0.075, 0.94)
const BORDER_COLOR := Color(0.32, 0.78, 0.86, 0.92)
const KEY_COLOR := Color(0.95, 0.76, 0.3, 1.0)

var _key_label: Label
var _prompt_label: Label
var _content: HBoxContainer
var _last_text := ""
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	custom_minimum_size = Vector2(360.0, 64.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	position.y = -128.0
	_create_style()
	_create_content()
	hide()


func show_prompt(prompt: String, key_name: String = "E") -> void:
	if prompt.is_empty():
		hide_prompt()
		return
	if not _prompt_label:
		_create_content()
	_key_label.text = key_name
	_prompt_label.text = prompt
	_last_text = prompt
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16)


func hide_prompt() -> void:
	_last_text = ""
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	visible = false


func get_prompt_text() -> String:
	return _last_text


func get_key_text() -> String:
	return _key_label.text if _key_label else ""


func _create_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)


func _create_content() -> void:
	if _content:
		return
	_content = HBoxContainer.new()
	_content.name = "Content"
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 12)
	add_child(_content)

	_key_label = Label.new()
	_key_label.name = "Key"
	_key_label.custom_minimum_size = Vector2(34.0, 34.0)
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.add_theme_font_size_override("font_size", 20)
	_key_label.add_theme_color_override("font_color", KEY_COLOR)
	_key_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_key_label.add_theme_constant_override("shadow_offset_x", 2)
	_key_label.add_theme_constant_override("shadow_offset_y", 2)
	_content.add_child(_key_label)

	_prompt_label = Label.new()
	_prompt_label.name = "Prompt"
	_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_content.add_child(_prompt_label)
