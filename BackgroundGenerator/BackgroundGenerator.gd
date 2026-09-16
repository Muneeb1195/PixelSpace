extends Control

@onready var background : ColorRect = $CanvasLayer/Background
@onready var starstuff : ColorRect = $StarStuff
@onready var nebulae : ColorRect = $Nebulae
@onready var particles : GPUParticles2D = $StarParticles
@onready var starcontainer : Node2D = $StarContainer
@onready var planetcontainer : Node2D = $PlanetContainer
@onready var planet_scene : PackedScene = preload("res://BackgroundGenerator/Planet.tscn")
@onready var big_star_scene : PackedScene = preload("res://BackgroundGenerator/BigStar.tscn")

var should_tile : bool = false
var reduce_background : bool = false
var mirror_size : Vector2i = Vector2(200,200)

@export var colorscheme: GradientTexture2D
var planet_objects : Array = []
var star_objects : Array = []

#func _ready() -> void:
	#OS.low_processor_usage_mode_sleep_usec = 10000

func set_mirror_size(new : Vector2) -> void:
	mirror_size = new

## The SubViewport runs in UPDATE_ONCE mode (see GUI.tscn) so the heavy
## full-screen shaders only render on demand. Kick one frame after any
## visual state change; use _keep_rendering() while particles settle.
func _request_render_once() -> void:
	var vp : Viewport = get_viewport()
	if vp is SubViewport:
		(vp as SubViewport).set_update_mode(SubViewport.UPDATE_ONCE)

func _keep_rendering() -> void:
	var vp : Viewport = get_viewport()
	if vp is SubViewport:
		(vp as SubViewport).set_update_mode(SubViewport.UPDATE_WHEN_VISIBLE)

func toggle_tile() -> void:
	should_tile = !should_tile
	starstuff.material.set_shader_parameter("should_tile", should_tile)
	nebulae.material.set_shader_parameter("should_tile", should_tile)

	_make_new_planets()
	_make_new_stars()
	_request_render_once()

func toggle_reduce_background() -> void:
	reduce_background = !reduce_background
	starstuff.material.set_shader_parameter("reduce_background", reduce_background)
	nebulae.material.set_shader_parameter("reduce_background", reduce_background)
	_request_render_once()

func generate_new() -> void:
	_keep_rendering()
	starstuff.material.set_shader_parameter("seed", randf_range(1.0, 10.0))
	starstuff.material.set_shader_parameter("pixels", max(size.x, size.y))
	
	var aspect : Vector2 = Vector2(1,1)
	if size.x > size.y:
		aspect = Vector2(size.x / size.y, 1.0)
	else:
		aspect = Vector2(1.0, size.y / size.x)
	
	starstuff.material.set_shader_parameter("uv_correct", aspect)
	nebulae.material.set_shader_parameter("seed", randf_range(1.0, 10.0))
	nebulae.material.set_shader_parameter("pixels", max(size.x, size.y))
	nebulae.material.set_shader_parameter("uv_correct", aspect)
	
	particles.restart()
	particles.speed_scale = 1.0
	particles.amount = 1
	particles.position = size * 0.5
	particles.process_material.set_shader_parameter("emission_box_extents", Vector3(size.x * 0.5, size.y*0.5,1.0))
	
	var p_amount : int = max(size.x,size.y)
	particles.amount = (p_amount)
	
	$PauseParticles.start()
	_make_new_planets()
	_make_new_stars()

func _make_new_stars() -> void:
	for s : Sprite2D in star_objects:
		s.queue_free()
	star_objects = []
	
	var star_amount : int = int(max(size.x, size.y) / 20)
	star_amount = max(star_amount, 1)
	var star_count : int = randi() % star_amount
	for i : int in star_count:
		_place_big_star()

func _make_new_planets() -> void:
	for p : Sprite2D in planet_objects:
		p.queue_free()
	planet_objects = []

	var planet_amount : int = randi_range(5,10) if size.x > 1500 else randi_range(2,5)#int(size.x * size.y) / 8000
	var planet_count : int = randi() % planet_amount
	for i : int in planet_count:
		_place_planet()

func _set_new_colors(new_scheme : GradientTexture2D, new_background : Color) -> void:
	colorscheme = new_scheme

	starstuff.material.set_shader_parameter("colorscheme", colorscheme)
	nebulae.material.set_shader_parameter("colorscheme", colorscheme)
	nebulae.material.set_shader_parameter("background_color", new_background)
	
	particles.process_material.set_shader_parameter("colorscheme", colorscheme)
	for p : Sprite2D in planet_objects:
		p.material.set_shader_parameter("colorscheme", colorscheme)
	for s : Sprite2D in star_objects:
		s.material.set_shader_parameter("colorscheme", colorscheme)
	_request_render_once()

func _place_planet() -> void:
	var min_size : int = min(size.x, size.y)
	var _scale : Vector2 = Vector2(1,1)*(randf_range(0.2, 0.7)*randf_range(0.5, 1.0)*min_size*0.005)
	
	var pos : Vector2 = Vector2()
	if (should_tile):
		var offs : float = _scale.x * 100.0 * 0.5
		pos = Vector2(int(randf_range(offs, size.x - offs)), int(randf_range(offs, size.y - offs)))
	else:
		pos = Vector2(int(randf_range(0, size.x)), int(randf_range(0, size.y)))
	
	var planet : Sprite2D = planet_scene.instantiate()
	planet.scale = _scale
	planet.position = pos
	planetcontainer.add_child(planet)
	planet_objects.append(planet)

func _place_big_star() -> void:
	var pos : Vector2 = Vector2()
	if (should_tile):
		var offs : float = 10.0
		pos = Vector2(int(randf_range(offs, size.x - offs)), int(randf_range(offs, size.y - offs)))
	else:
		pos = Vector2(int(randf_range(0, size.x)), int(randf_range(0, size.y)))
	
	var star : Sprite2D = big_star_scene.instantiate()
	star.position = pos
	starcontainer.add_child(star)
	star_objects.append(star)

func _on_PauseParticles_timeout() -> void:
	particles.speed_scale = 0.0
	particles.emitting = false
	# Particles have settled: freeze the viewport until the next change.
	_request_render_once()

func set_background_color(c : Color) -> void:
	background.color = c
	nebulae.material.set_shader_parameter("background_color", c)
	_request_render_once()

func toggle_dust() -> void:
	starstuff.visible = !starstuff.visible
	_request_render_once()

func toggle_stars() -> void:
	starcontainer.visible = !starcontainer.visible
	particles.visible = !particles.visible
	_request_render_once()

func toggle_nebulae() -> void:
	$Nebulae.visible = !$Nebulae.visible
	_request_render_once()

func toggle_planets() -> void:
	planetcontainer.visible = !planetcontainer.visible
	_request_render_once()

func toggle_transparancy() -> void:
	$CanvasLayer/Background.visible = !$CanvasLayer/Background.visible
	_request_render_once()

## Correct spelling; kept the old name as an alias (it is connected to UI
## and may be referenced from .tscn files or forks).
func toggle_transparency() -> void:
	toggle_transparancy()
