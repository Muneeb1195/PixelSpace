extends Control


@onready var generator : BackgroundGenerator = $SubViewport/BackgroundGenerator
@onready var viewport : SubViewport = $SubViewport
@onready var global_scheme : GradientTexture2D = preload("res://BackgroundGenerator/Colorscheme.tres")
@onready var label_3: Label = $HBoxContainer/ColorRect/Settings/Label3
@onready var seed_input: LineEdit = $HBoxContainer/ColorRect/Settings/SeedRow/SeedInput
@onready var seed_lock: CheckBox = $HBoxContainer/ColorRect/Settings/SeedRow2/SeedLock
@onready var seed_label: Label = $HBoxContainer/ColorRect/Settings/SeedRow2/SeedLabel
@onready var preset_option: OptionButton = $HBoxContainer/ColorRect/Settings/PresetRow/PresetOption
@onready var format_option: OptionButton = $HBoxContainer/ColorRect/Settings/FormatRow/FormatOption
@onready var quality_slider: HSlider = $HBoxContainer/ColorRect/Settings/QualRow/QualitySlider
@onready var quality_val: Label = $HBoxContainer/ColorRect/Settings/QualRow/QualityVal
@onready var batch_count: SpinBox = $HBoxContainer/ColorRect/Settings/BatchRow/BatchCount
@onready var batch_export_btn: Button = $HBoxContainer/ColorRect/Settings/BatchRow/BatchExport
@onready var new_button: Button = $HBoxContainer/ColorRect/Settings/NewButton
@onready var export_button: Button = $HBoxContainer/ColorRect/Settings/ExportButton
@onready var layers_check: CheckBox = $HBoxContainer/ColorRect/Settings/LayersCheck
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
var _applying_preset : bool = false
## 0 = PNG, 1 = JPG, 2 = WebP (desktop only; web download stays PNG).
var export_format : int = 0
var export_quality : float = 0.9
var _batch_remaining : int = 0

func _ready() -> void:
	randomize()
	current_seed = randi()
	seed(current_seed)
	path = _resolve_export_dir()
	_apply_platform_resolution_caps()
	_populate_formats()
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
	# Lock the controls that would corrupt a capture in flight (New resizes
	# the viewport; Batch starts its own capture chain).
	export_button.disabled = true
	new_button.disabled = true
	batch_export_btn.disabled = true
	$SubViewport/Camera1.enabled = false
	$SubViewport/Camera2.enabled = true
	viewport.set_update_mode(SubViewport.UPDATE_ONCE)
	$SaveTimer.start()

func export_image(layer : String = "") -> void:
	var img : Image
	img = Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
	var viewport_img : Image = viewport.get_texture().get_image()

	img.blit_rect(viewport_img, Rect2(0,0,new_size.x,new_size.y), Vector2(0,0))

	save_image(img, layer)

func save_image(img : Image, layer : String = "") -> void:
	# Layers are always PNG: only PNG carries the alpha parallax needs,
	# and the suffix keeps them next to their composite.
	var suffix : String = ("_" + layer) if not layer.is_empty() else ""
	if OS.has_feature("web"):
		var filesaver : Node = get_tree().root.get_node("/root/HTML5File")
		filesaver.save_image(img, "Space Background" + suffix)
	else:
		var stamp : String = Time.get_datetime_string_from_system().replace(":", "-")
		# Seed in the name: reproducible and collision-free for batch runs
		# landing inside the same second.
		var ext : String = "png"
		if layer.is_empty():
			if export_format == 1:
				ext = "jpg"
			elif export_format == 2:
				ext = "webp"
		var target : String = "%s/Space Background %d_%s%s.%s" % [path, current_seed, stamp, suffix, ext]
		var err : Error
		if ext == "jpg":
			err = img.save_jpg(target, export_quality)
		elif ext == "webp":
			err = img.save_webp(target, true, export_quality)
		else:
			err = img.save_png(target)
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
	if layers_check.button_pressed:
		for layer : String in BackgroundGenerator.LAYER_NAMES:
			generator.capture_layer_begin(layer)
			viewport.set_update_mode(SubViewport.UPDATE_ONCE)
			await RenderingServer.frame_post_draw
			export_image(layer)
		generator.capture_layer_end()
	$SubViewport/Camera1.enabled = true
	$SubViewport/Camera2.enabled = false
	viewport.set_update_mode(SubViewport.UPDATE_ONCE)
	_exporting = false
	if _batch_remaining > 0:
		_batch_next()
	else:
		export_button.disabled = false
		new_button.disabled = false
		batch_export_btn.disabled = false

func _populate_formats() -> void:
	format_option.add_item("PNG")
	format_option.add_item("JPG")
	format_option.add_item("WebP")

func _on_FormatOption_item_selected(index : int) -> void:
	export_format = index
	quality_slider.editable = index != 0

func _on_QualitySlider_value_changed(value : float) -> void:
	quality_val.text = str(int(value))
	export_quality = value / 100.0

## Batch renders N fresh variations back-to-back. Each item waits out the
## 0.5s particle settle (BatchTimer) before capturing, like a manual export.
func _on_BatchExport_pressed() -> void:
	if _exporting or _batch_remaining > 0:
		return
	_batch_remaining = int(batch_count.value)
	export_button.disabled = true
	new_button.disabled = true
	batch_export_btn.disabled = true
	_batch_next()

func _batch_next() -> void:
	if _batch_remaining <= 0:
		return
	_batch_remaining -= 1
	current_seed = randi()
	seed(current_seed)
	_update_seed_ui()
	_generate_new()
	$BatchTimer.start()

func _on_BatchTimer_timeout() -> void:
	_on_ExportButton_pressed()

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
	if not _applying_preset:
		preset_option.select(0)

func _on_PixelsWidth_value_changed(value : int) -> void:
	value = clamp(value, 100, _max_export_px())
	new_size.x = int(value)
	if not _applying_preset:
		preset_option.select(0)


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
	_populate_presets()

## Wallpaper-size presets, filtered by the platform cap. The list is built
## in code (not tscn) so over-cap entries never appear on mobile/web.
## OptionButton.select() does not emit, so manual SpinBox edits can safely
## reset the display to Custom via _applying_preset.
const RES_PRESETS : Array = [
	["Custom", Vector2i(0, 0)],
	["HD 1280x720", Vector2i(1280, 720)],
	["FHD 1920x1080", Vector2i(1920, 1080)],
	["QHD 2560x1440", Vector2i(2560, 1440)],
	["4K 3840x2160", Vector2i(3840, 2160)],
	["Phone 1080x2400", Vector2i(1080, 2400)],
	["Square 1080", Vector2i(1080, 1080)],
	["Square 2048", Vector2i(2048, 2048)],
]

func _populate_presets() -> void:
	preset_option.clear()
	var cap : int = _max_export_px()
	for p : Array in RES_PRESETS:
		var dims : Vector2i = p[1]
		if dims.x == 0 or (dims.x <= cap and dims.y <= cap):
			preset_option.add_item(p[0])
			preset_option.set_item_metadata(preset_option.item_count - 1, dims)

func _on_PresetOption_item_selected(index : int) -> void:
	var dims : Vector2i = preset_option.get_item_metadata(index)
	if dims.x <= 0:
		return
	var spin_w : SpinBox = $HBoxContainer/ColorRect/Settings/HBoxContainer/PixelsWidth
	var spin_h : SpinBox = $HBoxContainer/ColorRect/Settings/HBoxContainer2/PixelsHeight
	_applying_preset = true
	spin_w.value = dims.x
	spin_h.value = dims.y
	_applying_preset = false
