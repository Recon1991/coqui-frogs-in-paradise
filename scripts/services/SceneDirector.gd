extends Node
signal ready_signal
var is_ready := false
var _switching := false

const SCN_DISCLAIMER := "res://scenes/Disclaimer.tscn"
const SCN_INTRO      := "res://scenes/Intro.tscn"
const SCN_MENU       := "res://scenes/MainMenu.tscn"
const SCN_GAME       := "res://scenes/Main.tscn"

func _ready() -> void:
	await _await_ready(ConfigService, "ConfigService")
	await _await_ready(AudioService, "AudioService")
	await _await_ready(I18n, "I18n")
	# NEW: wait for Transition as well (if present)
	await _await_ready(Transition, "Transition")
	is_ready = true
	ready_signal.emit()
	call_deferred("_start")

func _start() -> void:
	print("[SceneDirector] start → disclaimer")
	await _goto_with_fade(SCN_DISCLAIMER)

func _await_ready(svc: Object, label: String) -> void:
	if typeof(svc) != TYPE_OBJECT or not is_instance_valid(svc):
		print("[SceneDirector] %s not present; proceeding" % label)
		return
	if "is_ready" in svc and svc.is_ready:
		print("[SceneDirector] %s already ready" % label)
		return
	if svc.has_signal("ready_signal"):
		print("[SceneDirector] waiting for %s…" % label)
		await svc.ready_signal
		print("[SceneDirector] %s is ready" % label)
	else:
		print("[SceneDirector] %s has no ready signal; proceeding" % label)

func _has_transition() -> bool:
	return typeof(Transition) == TYPE_OBJECT \
		and is_instance_valid(Transition) \
		and Transition.has_method("fade_out") \
		and Transition.has_method("fade_in")

func goto_disclaimer() -> void:
	await _goto_with_fade(SCN_DISCLAIMER)

func goto_intro() -> void:
	await _goto_with_fade(SCN_INTRO)

func goto_menu() -> void:
	await _goto_with_fade(SCN_MENU)

func goto_gameplay() -> void:
	await _goto_with_fade(SCN_GAME)

func _goto_with_fade(path: String, fade_out_dur := 0.25, fade_in_dur := 0.20) -> void:
	if _switching:
		print("[SceneDirector] already switching, ignoring", path)
		return
	_switching = true

	if not ResourceLoader.exists(path):
		push_error("[SceneDirector] Scene not found: " + path)
		_switching = false
		return

	print("[SceneDirector] → fade_out + switch:", path)
	if _has_transition():
		await Transition.fade_out(fade_out_dur)
	else:
		await get_tree().process_frame

	get_tree().call_deferred("change_scene_to_file", path)
	await get_tree().process_frame

	if _has_transition():
		await Transition.fade_in(fade_in_dur)

	print("[SceneDirector] switched to", path)
	_switching = false
