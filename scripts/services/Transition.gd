# res://scripts/services/Transition.gd
extends CanvasLayer

signal ready_signal
signal faded_out
signal faded_in

@export var color: Color = Color.BLACK
@export var block_input: bool = true
@export var start_opaque: bool = false
@export var default_trans: int = Tween.TRANS_SINE
@export var default_ease:  int = Tween.EASE_IN_OUT

var is_ready := false
var _rect: ColorRect
var _tween: Tween
var _mode: String = "fade"  # "fade" or "shader"

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_ensure_rect()
	is_ready = true
	ready_signal.emit()

func _ensure_rect() -> void:
	if _rect: return
	_rect = ColorRect.new()
	_rect.color = color
	_rect.modulate.a = 1.0 if start_opaque else 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP if block_input else Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

# ---------- Effect selection ----------
func use_fade() -> void:
	_mode = "fade"
	if _rect: _rect.material = null

func use_wipe(angle_deg: float = 0.0, softness: float = 0.03) -> void:
	_mode = "shader"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/transition_wipe.gdshader")
	mat.set_shader_parameter("angle", deg_to_rad(angle_deg))
	mat.set_shader_parameter("softness", softness)
	_rect.material = mat

func use_circle(center: Vector2 = Vector2(0.5, 0.5), softness: float = 0.03, invert: bool = false) -> void:
	_mode = "shader"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/transition_circle.gdshader")
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("softness", softness)
	mat.set_shader_parameter("invert", invert)
	_rect.material = mat

func use_dissolve(noise: Texture2D, softness: float = 0.06, scale: float = 2.0, invert: bool = false) -> void:
	_mode = "shader"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/transition_dissolve.gdshader")
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("softness", softness)
	mat.set_shader_parameter("scale", scale)
	mat.set_shader_parameter("invert", invert)
	_rect.material = mat

# ---------- Progress driver ----------
func _set_progress(p: float) -> void:
	if _mode == "fade" or _rect.material == null:
		_rect.modulate.a = clamp(p, 0.0, 1.0)
	else:
		_rect.material.set_shader_parameter("progress", clamp(p, 0.0, 1.0))

func get_progress() -> float:
	if _mode == "fade" or _rect.material == null:
		return _rect.modulate.a
	return float(_rect.material.get_shader_parameter("progress"))

# ---------- Play ----------
func fade_to(target: float, dur := 0.25, trans := default_trans, ease := default_ease) -> void:
	_ensure_rect()
	target = clamp(target, 0.0, 1.0)
	if dur <= 0.0 or is_equal_approx(get_progress(), target):
		_set_progress(target)
		if is_equal_approx(target, 0.0): faded_in.emit()
		elif is_equal_approx(target, 1.0): faded_out.emit()
		return

	if _tween: _tween.kill()
	_tween = create_tween().set_trans(trans).set_ease(ease)
	_tween.tween_method(_set_progress, get_progress(), target, dur)
	await get_tree().create_timer(dur).timeout
	_set_progress(target)
	_tween = null

	if is_equal_approx(target, 0.0): faded_in.emit()
	elif is_equal_approx(target, 1.0): faded_out.emit()

func fade_out(dur := 0.25, trans := default_trans, ease := default_ease) -> void:
	await fade_to(1.0, dur, trans, ease)

func fade_in(dur := 0.25, trans := default_trans, ease := default_ease) -> void:
	await fade_to(0.0, dur, trans, ease)
