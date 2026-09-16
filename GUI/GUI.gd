extends Control


@onready var generator : Control = $SubViewport/BackgroundGenerator
@onready var viewport : SubViewport = $SubViewport
@onready var global_scheme : GradientTexture2D = preload("res://BackgroundGenerator/Colorscheme.tres")
@onready var label_3: Label = $HBoxContainer/ColorRect/Settings/Label3

var new_size : Vector2i = Vector2i(200,200)
var path : String
var _exporting : bool = false

func _ready() -> void:
	randomize()
	path = _resolve_export_dir()
	_apply_platform_resolution_caps()
	_generate_new()
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
	_generate_new()

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
		var err : Error = img.save_png(path + "/Space Background " + stamp + ".png")
		if err != OK:
			push_error("PixelSpace: failed to save PNG to %s (error %d)" % [path, err])

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
	generator.toggle_transparancy()
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
