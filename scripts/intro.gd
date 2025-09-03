# res://scripts/ui/Intro.gd
extends CanvasLayer

@export var delay_sec: float = 1.6
var _done: bool = false

func _ready() -> void:
	_start()

func _start() -> void:
	await get_tree().create_timer(delay_sec).timeout
	_finish()

func _unhandled_input(e: InputEvent) -> void:
	if _done:
		return
	var proceed: bool = false
	if e is InputEventKey:
		var k: InputEventKey = e
		proceed = k.pressed and not k.echo
	elif e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		proceed = mb.pressed
	elif e is InputEventScreenTouch:
		var st: InputEventScreenTouch = e
		proceed = st.pressed

	if proceed:
		_finish()
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if _done:
		return
	_done = true
	set_process_unhandled_input(false)
	SceneDirector.goto_menu()
