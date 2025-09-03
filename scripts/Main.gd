extends Node

@onready var ui := $UILayer
@onready var hud := $UILayer/HUD
@onready var shop := $UILayer/ShopPanel
@onready var settings := $UILayer/SettingsPanel
@onready var overlay := $UILayer/ModalOverlay
@onready var game := $GameScene

func _ready() -> void:
	_hide_all_panels()
	# When HUD/Shop/Settings are replaced by instanced scenes, keep the same node paths or export NodePaths.
	if hud.has_signal("shop_requested"):
		hud.shop_requested.connect(toggle_shop)
	if hud.has_signal("settings_requested"):
		hud.settings_requested.connect(toggle_settings)
	if hud.has_signal("serene_toggled"):
		hud.serene_toggled.connect(_set_serene)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_open_shop"):
		toggle_shop()
	elif event.is_action_pressed("ui_open_settings"):
		toggle_settings()
	elif event.is_action_pressed("ui_toggle_serene"):
		_toggle_serene_button()

func toggle_shop() -> void:
	var opening: bool = not shop.visible
	_set_modal(opening)
	shop.visible = opening
	settings.visible = false

func toggle_settings() -> void:
	var opening: bool = not settings.visible
	_set_modal(opening)
	settings.visible = opening
	shop.visible = false

func _set_modal(opening: bool) -> void:
	overlay.visible = opening
	get_tree().paused = opening
	# Godot 4.x: use process_mode (Inspector: Process → Mode)
	# Pausable = stops when the tree is paused; WhenPaused = keeps processing while paused.
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _hide_all_panels() -> void:
	shop.visible = false
	settings.visible = false
	overlay.visible = false
	get_tree().paused = false

func _toggle_serene_button() -> void:
	if not hud:
		return
	if hud.has_method("toggle_serene_mode"):
		hud.toggle_serene_mode()

func _set_serene(active: bool) -> void:
	# Dim UI when serene is active.
	ui.modulate.a = 0.8 if active else 1.0
	# If AudioService is an Autoload (singleton), access it directly or via /root.
	if has_node("/root/AudioService"):
		get_node("/root/AudioService").set_serene_mix(active)
