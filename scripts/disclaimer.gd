extends CanvasLayer

@onready var text_label:  Label   = %DisclaimerText
@onready var slider:      HSlider = %VolumeSlider
@onready var percent_label: Label = %VolumePercent
@onready var continue_btn: Button = %ContinueButton

func _ready() -> void:
	text_label.text = I18n.t("disclaimer.text")
	var v: float = ConfigService.get_master_volume_linear()
	slider.value = v
	slider.value_changed.connect(_on_volume_changed)
	continue_btn.text = I18n.t("ui.continue")
	continue_btn.pressed.connect(_on_continue)
	_update_percent(slider.value)

func _on_volume_changed(v: float) -> void:
	AudioService.set_master_volume_linear(v) # live preview
	ConfigService.set_master_volume_linear(v)
	_update_percent(v)

func _update_percent(v: float) -> void:
	percent_label.text = str(int(round(v * 100.0))) + "%"

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept"):
		_on_continue()

func _on_continue() -> void:
	ConfigService.set_master_volume_linear(slider.value) # persist
	SceneDirector.goto_intro()
