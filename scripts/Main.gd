extends Control

@onready var gold_label: Label = %GoldLabel
@onready var rate_label: Label = %RateLabel
@onready var click_button: Button = %ClickButton
@onready var save_button: Button = %SaveButton
@onready var reset_button: Button = %ResetButton
@onready var miner_button: Button = %MiningButton
@onready var drill_button: Button = %DrillButton

var _ui_timer: Timer

func _ready() -> void:
	click_button.pressed.connect(_on_click)
	save_button.pressed.connect(_on_save)
	reset_button.pressed.connect(_on_reset)
	miner_button.pressed.connect(func(): _buy_upgrade("miner"))
	drill_button.pressed.connect(func(): _buy_upgrade("drill"))

	_ui_timer = Timer.new()
	_ui_timer.wait_time = 0.25
	_ui_timer.one_shot = false
	_ui_timer.autostart = true
	add_child(_ui_timer)
	_ui_timer.timeout.connect(_update_ui)

	_update_ui()

func _on_click() -> void:
	GameState.click()
	_update_ui()

func _buy_upgrade(id: String) -> void:
	if GameState.buy(id):
		_update_ui()

func _on_save() -> void:
	GameState.save_game()

func _on_reset() -> void:
	GameState.hard_reset()
	_update_ui()

func _update_ui() -> void:
	gold_label.text = "Gold: %s" % _fmt_int(GameState.gold)
	rate_label.text = "Rate: %s / sec" % _fmt_float(GameState.rate)
	miner_button.text = "Buy Miner (%d)  —  Cost: %s" % [int(GameState.upgrades["miner"].level), _fmt_int(GameState.get_upgrade_cost("miner"))]
	drill_button.text = "Buy Drill (%d)  —  Cost: %s" % [int(GameState.upgrades["drill"].level), _fmt_int(GameState.get_upgrade_cost("drill"))]
	miner_button.disabled = not GameState.can_buy("miner")
	drill_button.disabled = not GameState.can_buy("drill")

func _fmt_int(v: float) -> String:
	# Tiny pretty-format for readability
	return String.num_uint64(int(v))

func _fmt_float(v: float) -> String:
	return String.num(v, 2)
