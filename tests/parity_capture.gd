extends SceneTree
## Pixel-parity capture harness.
##
## Reseeds the global RNG after the scene's _ready() so generation is fully
## deterministic, waits past the 0.5s particle-freeze, captures the viewport
## and prints a SHA256 of the raw pixels (hash the pixels, not the file, to
## dodge encoder metadata).
##
## NOTE: nodes added in _initialize() don't get _ready until the first frame,
## so all setup is deferred into _process ticks.
##
## NOTE: needs a real renderer — headless runs use the dummy driver and
## capture blank images. Run with a display (x11/wayland) and GPU:
##   godot --display-driver wayland --rendering-driver vulkan \
##     --rendering-method mobile --audio-driver Dummy \
##     --path <project> --script res://tests/parity_capture.gd \
##     -- <seed> <px> <out.png>
## Compare two builds by running the same <seed>/<px> and diffing PARITY_HASH.

var _gui: Control
var _tick := 0
var _wait := 0.0
var _captured := false
var _seed_val := 1234
var _px := 512
var _out := "/tmp/parity.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seed_val = int(args[0])
	if args.size() > 1:
		_px = int(args[1])
	if args.size() > 2:
		_out = String(args[2])

func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 2 and _gui == null:
		var packed: PackedScene = load("res://GUI/GUI.tscn")
		_gui = packed.instantiate() as Control
		root.add_child(_gui)
	elif _tick == 4 and _gui != null:
		# _ready() has run by now: reseed for determinism, then regenerate.
		seed(_seed_val)
		_gui.new_size = Vector2i(_px, _px)
		_gui._generate_new()
	elif _tick > 4 and _gui != null:
		_wait += _delta
		if _wait >= 2.0 and not _captured:
			_captured = true
			_capture()
			return true
	if _tick > 2000:
		printerr("PARITY_TIMEOUT")
		return true
	return false

func _capture() -> void:
	var vp: SubViewport = _gui.get_node("SubViewport") as SubViewport
	var tex: Image = vp.get_texture().get_image()
	if tex.is_empty():
		printerr("PARITY_BLANK: no rendered image (dummy renderer?)")
		return
	var out := Image.create_empty(_px, _px, false, Image.FORMAT_RGBA8)
	out.blit_rect(tex, Rect2i(0, 0, _px, _px), Vector2i.ZERO)
	var err := out.save_png(_out)
	if err != OK:
		printerr("PARITY_SAVE_FAIL")
		return
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(out.get_data())
	print("PARITY_HASH:" + ctx.finish().hex_encode())
