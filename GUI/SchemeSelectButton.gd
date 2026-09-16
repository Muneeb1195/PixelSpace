extends Button

## Emitted instead of reaching up to a hardcoded scene-tree path, so this
## button works no matter where it is instanced or what the root is named.
signal scheme_chosen(scheme: PackedColorArray)

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
	scheme_chosen.emit(colorscheme)

func _on_Button_pressed() -> void:
	scheme_chosen.emit(colorscheme)
