extends Control


@onready var generator : Control = $SubViewport/BackgroundGenerator
@onready var viewport : SubViewport = $SubViewport
@onready var global_scheme : GradientTexture2D = preload("res://BackgroundGenerator/Colorscheme.tres")
@onready var label_3: Label = $HBoxContainer/ColorRect/Settings/Label3
@onready var seed_input: LineEdit = $HBoxContainer/ColorRect/Settings/SeedRow/SeedInput
@onready var seed_lock: CheckBox = $HBoxContainer/ColorRect/Settings/SeedRow2/SeedLock
@onready var seed_label: Label = $HBoxContainer/ColorRect/Settings/SeedRow2/SeedLabel
@onready var auto_counts_box: CheckBox = $HBoxContainer/ColorRect/Settings/AutoCounts
@onready var planets_slider: HSlider = $HBoxContainer/ColorRect/Settings/PlanetsRow/PlanetsSlider
@onready var planets_val: Label = $HBoxContainer/ColorRect/Settings/PlanetsRow/PlanetsVal
@onready var stars_slider: HSlider = $HBoxContainer/ColorRect/Settings/StarsRow/StarsSlider
@onready var stars_val: Label = $HBoxContainer/ColorRect/Settings/StarsRow/StarsVal
@onready var dust_val: Label = $HBoxContainer/ColorRect/Settings/DustRow/DustVal
@onready var nebula_val: Label = $HBoxContainer/ColorRect/Settings/NebulaRow/NebulaVal

var new_size : Vector2i = Vector2i(200,200)
var path : String
var _exporting : bool = false
var current_seed : int = 0
var seed_locked : bool = false

func _ready() -> void:
	randomize()
	current_seed = randi()
	seed(current_seed)
	path = _resolve_export_dir()
	_apply_platform_resolution_caps()
	_connect_scheme_buttons()
	_generate_new()
	_update_seed_ui()
	OS.low_processor_usage_mode = true
	if OS.get_name() == "Android":
		OS.request_permissions()
	label_3.text += path

## OS.get_system_dir can return an empty path (e.g. sandboxed platforms or
## denied storage); fall back to the app's user data dir so export never
## builds a broken "//Space Background ..." path.
func _resolve_export_dir() -> String:
	var pictures : String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures.is_empty():
		pictures = OS.get_user_data_dir()
	return pictures

func _generate_new() -> void:
	$SubViewport.size = new_size
	generator.custom_minimum_size = new_size
	generator.size = new_size
	generator.set_mirror_size(new_size)
	$SubViewport/Camera1.zoom = new_size/viewport.size
	$SubViewport/Camera1.offset = new_size * 0.5
	
	var aspect : Vector2 = Vector2.ONE
	if new_size.x > new_size.y:
		aspect = Vector2(new_size.y / new_size.x, 1.0)
	else:
		aspect = Vector2(1.0, new_size.x / new_size.y)
	
	$HBoxContainer/Control/MarginContainer/TextureRect.size = aspect * 600

	await get_tree().process_frame
	$HBoxContainer/Control/MarginContainer/TextureRect.size = Vector2(600,600)
	generator.generate_new()

func _on_NewButton_pressed() -> void:
	if not seed_locked:
		current_seed = randi()
	seed(current_seed)
	_update_seed_ui()
	_generate_new()

## Replays the exact RNG stream: same seed + size + scheme + toggles
## reproduces the same image (see tests/parity_capture.gd).
func _update_seed_ui() -> void:
	seed_label.text = "current: %d" % current_seed
	seed_input.placeholder_text = str(current_seed)

func _on_SeedApply_pressed() -> void:
	var txt : String = seed_input.text.strip_edges()
	if not txt.is_valid_int():
		seed_input.text = ""
		return
	current_seed = int(txt)
	seed_locked = true
	seed_lock.button_pressed = true
	seed_input.text = ""
	seed(current_seed)
	_update_seed_ui()
	_generate_new()

func _on_SeedLock_toggled(pressed_on : bool) -> void:
	seed_locked = pressed_on

## Dragging a count slider implies manual control: drop out of auto mode
## without emitting (avoids a redundant regenerate per drag tick).
func _manual_counts() -> void:
	if auto_counts_box.button_pressed:
		auto_counts_box.set_pressed_no_signal(false)
		planets_slider.editable = true
		stars_slider.editable = true

func _on_AutoCounts_toggled(pressed_on : bool) -> void:
	generator.set_auto_counts(pressed_on)
	planets_slider.editable = not pressed_on
	stars_slider.editable = not pressed_on

func _on_PlanetsSlider_value_changed(value : float) -> void:
	planets_val.text = str(int(value))
	_manual_counts()
	generator.set_planet_count(int(value))

func _on_StarsSlider_value_changed(value : float) -> void:
	stars_val.text = "%d%%" % int(value)
	_manual_counts()
	generator.set_star_density(value / 100.0)

func _on_DustSlider_value_changed(value : float) -> void:
	dust_val.text = "%d%%" % int(value)
	generator.set_dust_scale(value / 100.0)

func _on_NebulaSlider_value_changed(value : float) -> void:
	nebula_val.text = "%d%%" % int(value)
	generator.set_nebula_scale(value / 100.0)

func _on_ExportButton_pressed() -> void:
	if _exporting:
		return
	_exporting = true
	$HBoxContainer/ColorRect/Settings/ExportButton.disabled = true
	$SubViewport/Camera1.enabled = false
	$SubViewport/Camera2.enabled = true
	viewport.set_update_mode(SubViewport.UPDATE_ONCE)
	$SaveTimer.start()

func export_image() -> void:
	var img : Image
	img = Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
	var viewport_img : Image = viewport.get_texture().get_image()

	img.blit_rect(viewport_img, Rect2(0,0,new_size.x,new_size.y), Vector2(0,0))

	save_image(img)

func save_image(img : Image) -> void:
	if OS.has_feature("web"):
		var filesaver : Node = get_tree().root.get_node("/root/HTML5File")
		filesaver.save_image(img, "Space Background")
	else:
		var stamp : String = Time.get_datetime_string_from_system().replace(":", "-")
		var target : String = path + "/Space Background " + stamp + ".png"
		var err : Error = img.save_png(target)
		if err != OK:
			push_error("PixelSpace: failed to save PNG to %s (error %d)" % [path, err])
			_show_export_error(target, err)

func _show_export_error(target : String, err : Error) -> void:
	var dialog : AcceptDialog = $ErrorDialog
	dialog.dialog_text = "Could not save the image to:\n%s\n\nCheck the folder exists and is writable. (Error %d)" % [target, err]
	dialog.popup_centered()

func _on_SaveTimer_timeout() -> void:
	# Ensure the Camera2 UPDATE_ONCE frame has landed before reading pixels.
	await RenderingServer.frame_post_draw
	export_image()
	$SubViewport/Camera1.enabled = true
	$SubViewport/Camera2.enabled = false
	viewport.set_update_mode(SubViewport.UPDATE_ONCE)
	_exporting = false
	$HBoxContainer/ColorRect/Settings/ExportButton.disabled = false

func select_colorscheme(scheme : PackedColorArray) -> void:
	$SubViewport/BackgroundGenerator.set_background_color(scheme[0])
	global_scheme.gradient.colors = scheme.slice(1,8)

## Preset buttons announce themselves via `scheme_chosen`; wiring by signal
## keeps this working for any number of presets and any root node name.
func _connect_scheme_buttons() -> void:
	var list : VBoxContainer = $HBoxContainer/ColorRect/Settings/ScrollContainer/VBoxContainer
	for child : Node in list.get_children():
		if child.has_signal("scheme_chosen"):
			child.connect("scheme_chosen", select_colorscheme)

func _on_EnableStars_pressed() -> void:
	generator.toggle_stars()

func _on_EnableDust_pressed() -> void:
	generator.toggle_dust()

func _on_EnableNebulae_pressed() -> void:
	generator.toggle_nebulae()

func _on_EnablePlanets_pressed() -> void:
	generator.toggle_planets()

func _on_EnableReduceBackground_pressed() -> void:
	generator.toggle_reduce_background()

func _on_EnableTile_pressed() -> void:
	generator.toggle_tile()

func _on_PixelsHeight_value_changed(value : int) -> void:
	value = clamp(value, 100, _max_export_px())
	new_size.y = int(value)

func _on_PixelsWidth_value_changed(value : int) -> void:
	value = clamp(value, 100, _max_export_px())
	new_size.x = int(value)


func _on_EnableTransparency_pressed() -> void:
	generator.toggle_transparency()
	$HBoxContainer/Control/ColorRect.visible = !$HBoxContainer/Control/ColorRect.visible
	# The checkerboard only matters when the background is transparent; while
	# the opaque rect covers it, hide it to skip a full-screen texture sample.
	$HBoxContainer/Control/TextureRect2.visible = !$HBoxContainer/Control/ColorRect.visible

## Mobile GPUs and web canvases stall on huge backing stores; desktop keeps
## the full 5k range. Preview and export share new_size, so one cap covers both.
func _max_export_px() -> int:
	if OS.has_feature("web") or OS.get_name() == "Android":
		return 2048
	return 5000

func _apply_platform_resolution_caps() -> void:
	var cap : int = _max_export_px()
	var spin_w : SpinBox = $HBoxContainer/ColorRect/Settings/HBoxContainer/PixelsWidth
	var spin_h : SpinBox = $HBoxContainer/ColorRect/Settings/HBoxContainer2/PixelsHeight
	spin_w.max_value = cap
	spin_h.max_value = cap
	new_size.x = mini(new_size.x, cap)
	new_size.y = mini(new_size.y, cap)
