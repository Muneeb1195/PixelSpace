extends Button

@export var colorscheme: PackedColorArray
@onready var colorbutton_scene : PackedScene = preload("res://GUI/ColorPickerButton.tscn")

func _ready() -> void:
	# 13 presets x up to 9 pickers built eagerly = ~100 popups in one frame.
	# Defer so each button builds on its own idle tick; visuals unchanged.
	_build_swatches.call_deferred()

func _build_swatches() -> void:
	for i : int in colorscheme.size():
		var b : ColorPickerButton = ColorPickerButton.new()

		b.color = colorscheme[i]
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.connect("color_changed", Callable(self, "_on_color_changed").bind(i))
		$HBoxContainer.add_child(b)

func _on_color_changed(color : Color, index : int) -> void:
	colorscheme[index] = color
	get_tree().root.get_node("GUI").select_colorscheme(colorscheme)

func _on_Button_pressed() -> void:
	get_tree().root.get_node("GUI").select_colorscheme(colorscheme)
