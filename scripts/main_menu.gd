extends CanvasLayer

@onready var btn_continue: Button = %ContinueButton
@onready var btn_new:      Button = %NewGameButton
@onready var btn_settings: Button = %SettingsButton
@onready var btn_quit:     Button = %QuitButton

func _ready() -> void:
	btn_continue.text = I18n.t("menu.continue")
	btn_new.text      = I18n.t("menu.newgame")
	btn_settings.text = I18n.t("menu.settings")
	btn_quit.text     = I18n.t("menu.quit")

	btn_continue.pressed.connect(_continue)
	btn_new.pressed.connect(_new_game)
	btn_settings.pressed.connect(_settings)
	btn_quit.pressed.connect(_quit)

	# Optional: hide Continue if no save exists
	# btn_continue.visible = SaveService.has_save()

func _continue() -> void:
	SceneDirector.goto_gameplay()

func _new_game() -> void:
	GameState.currency = 0.0
	GameState.click_value = 1.0
	GameState.cps = 0.0
	SceneDirector.goto_gameplay()

func _settings() -> void:
	# Option A: go to gameplay and open settings panel
	SceneDirector.goto_gameplay()
	# Option B: load a dedicated Settings.tscn (we can wire this later)

func _quit() -> void:
	get_tree().quit()
	
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_focus_next"): # usually Tab
		Transition.use_fade()
		Transition.color = Color(1, 1, 1, 1)   # white flash
		await Transition.fade_out(0.6)
		await Transition.fade_in(0.6)
