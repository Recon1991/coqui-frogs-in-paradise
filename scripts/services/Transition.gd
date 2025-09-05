# res://scripts/services/Transition.gd
extends CanvasLayer

signal ready_signal
signal faded_out
signal faded_in

@export var color: Color = Color.BLACK
@export var block_input: bool = true
@export var start_opaque: bool = false

# Easing options
const EASE_SINE := 0
const EASE_QUAD := 1
@export var ease_type: int = EASE_SINE      # 0 = Sine, 1 = Quad
@export var ease_in_out: bool = true        # true: InOut, false: Out
@export var out_duration: float = 0.40      # fade to black
@export var in_duration:  float = 0.30      # fade from black

const _INPUT_BLOCK_THRESHOLD := 0.02

var is_ready: bool = false
var _rect: ColorRect = null
var _mode: String = "fade"  # "fade" or "shader" (we use fade by default)

func _ready() -> void:
	layer = 4096
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_ensure_rect()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	is_ready = true
	ready_signal.emit()

func _ensure_rect() -> void:
	if _rect != null:
		return
	_rect = ColorRect.new()
	_rect.color = color
	if start_opaque:
		_rect.modulate.a = 1.0
	else:
		_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.z_index = 4096
	add_child(_rect)

func _on_viewport_resized() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	_rect.position = Vector2.ZERO
	_rect.size = sz

# ---------- effect selection ----------
func use_fade() -> void:
	_mode = "fade"
	_ensure_rect()
	_rect.material = null
	if _rect.modulate.a < 0.0:
		_rect.modulate.a = 0.0
	if _rect.modulate.a > 1.0:
		_rect.modulate.a = 1.0

# (If you add shader effects later, call _apply_material(...) and keep _rect.modulate.a = 1.0)

# ---------- helpers ----------
func _update_mouse_filter() -> void:
	var p: float = get_progress()
	if block_input and p > _INPUT_BLOCK_THRESHOLD:
		_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_progress(p: float) -> void:
	var clamped: float = clamp(p, 0.0, 1.0)
	_rect.modulate.a = clamped
	_update_mouse_filter()

func get_progress() -> float:
	return _rect.modulate.a

func _ease01(t: float) -> float:
	# t in [0..1]
	if ease_type == EASE_SINE:
		if ease_in_out:
			return 0.5 - 0.5 * cos(PI * t)   # Sine InOut
		else:
			return sin(t * PI * 0.5)        # Sine Out
	else:
		# QUAD
		if ease_in_out:
			if t < 0.5:
				return 2.0 * t * t
			else:
				return 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5
		else:
			return 1.0 - pow(1.0 - t, 2.0)  # Quad Out

# ---------- manual animation (no Tween) ----------
func fade_to(target: float, dur: float = 0.25) -> void:
	_ensure_rect()
	var tgt: float = clamp(target, 0.0, 1.0)
	var start: float = get_progress()

	# instant path
	if dur <= 0.0 or is_equal_approx(start, tgt):
		_set_progress(tgt)
		if is_equal_approx(tgt, 0.0):
			faded_in.emit()
		elif is_equal_approx(tgt, 1.0):
			faded_out.emit()
		return

	# If increasing coverage, block immediately
	if block_input and tgt > start:
		_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var steps: int = max(1, int(ceil(dur * 60.0)))
	var step_time: float = dur / float(steps)

	for i in range(steps):
		var t: float = float(i + 1) / float(steps)  # 0→1
		var e: float = _ease01(t)
		var v: float = lerp(start, tgt, e)
		_set_progress(v)
		await get_tree().create_timer(step_time).timeout

	# snap to exact target & emit
	_set_progress(tgt)
	if is_equal_approx(tgt, 0.0):
		faded_in.emit()
	elif is_equal_approx(tgt, 1.0):
		faded_out.emit()

func fade_out(dur: float) -> void:
	await fade_to(1.0, dur)

func fade_in(dur: float) -> void:
	await fade_to(0.0, dur)
	
func fade_out_default() -> void:
	await fade_out(out_duration)

func fade_in_default() -> void:
	await fade_in(in_duration)
