extends Control

# --- references ---
@onready var gs := get_node("/root/GameState")  # autoload

# Containers
@onready var backyard_col: VBoxContainer = %BackyardCol
@onready var tree_col: VBoxContainer = %TreeCol
@onready var chorus_col: VBoxContainer = %ChorusCol

# Stats row
@onready var croaks_label: Label = %CroaksLabel
@onready var cps_label: Label = %CPSLabel
@onready var prestige_button: Button = %PrestigeButton

# Frogs
@onready var backyard_count: Label = %BackyardCountLabel
@onready var backyard_buy: Button = %BackyardBuyButton
@onready var tree_count: Label = %TreeCountLabel
@onready var tree_buy: Button = %TreeBuyButton
@onready var chorus_count: Label = %ChorusCountLabel
@onready var chorus_buy: Button = %ChorusBuyButton

# Habitats
@onready var water_tier: Label = %WaterTierLabel
@onready var water_buy: Button = %WaterBuyButton
@onready var foliage_tier: Label = %FoliageTierLabel
@onready var foliage_buy: Button = %FoliageBuyButton
@onready var shelter_tier: Label = %ShelterTierLabel
@onready var shelter_buy: Button = %ShelterBuyButton

# Bottom row
@onready var click_button: Button = %ClickButton
@onready var save_button: Button = %SaveButton
@onready var reset_button: Button = %ResetButton

var _ui_timer: Timer

func _ready() -> void:
	# button wiring
	backyard_buy.pressed.connect(func(): _buy_frog("backyard_coqui"))
	tree_buy.pressed.connect(func(): _buy_frog("tree_coqui"))
	chorus_buy.pressed.connect(func(): _buy_frog("chorus_leader"))

	water_buy.pressed.connect(func(): _buy_habitat("water"))
	foliage_buy.pressed.connect(func(): _buy_habitat("foliage"))
	shelter_buy.pressed.connect(func(): _buy_habitat("shelter"))

	click_button.pressed.connect(func(): gs.click())
	save_button.pressed.connect(gs.save_game)
	reset_button.pressed.connect(gs.hard_reset)
	prestige_button.pressed.connect(_do_prestige)

	# lightweight UI refresh loop (10 Hz)
	_ui_timer = Timer.new()
	_ui_timer.wait_time = 0.1
	_ui_timer.one_shot = false
	_ui_timer.autostart = true
	add_child(_ui_timer)
	_ui_timer.timeout.connect(update_ui)

	update_ui()

func _buy_frog(id: String) -> void:
	if gs.buy_frog(id):
		update_ui()

func _buy_habitat(id: String) -> void:
	if gs.buy_habitat(id):
		update_ui()

func _do_prestige() -> void:
	gs.do_prestige()
	update_ui()

func update_ui() -> void:
	# stats
	croaks_label.text = "Croaks: %s" % _fmt(gs.croaks)
	cps_label.text = "CPS: %s" % _fmt(gs.cps)

	var can_p: bool = gs.can_prestige()
	prestige_button.visible = can_p
	if can_p:
		var gain: int = gs.prestige_gain()
		prestige_button.text = "Call the Rains! (+%d Spirits)" % gain

	# cache current croaks once and reuse
	var c: float = gs.croaks

	# --- FROGS ---
	var n_back: int = int(gs.frogs.get("backyard_coqui", 0))
	var n_tree: int = int(gs.frogs.get("tree_coqui", 0))
	var n_chorus: int = int(gs.frogs.get("chorus_leader", 0))

	backyard_count.text = "Owned: %d" % n_back
	tree_count.text = "Owned: %d" % n_tree
	chorus_count.text = "Owned: %d" % n_chorus

	var cost_back: int = gs.frog_cost("backyard_coqui")
	var cost_tree: int = gs.frog_cost("tree_coqui")
	var cost_chorus: int = gs.frog_cost("chorus_leader")

	backyard_buy.text = "Buy (%s)" % _fmt(float(cost_back))
	tree_buy.text     = "Buy (%s)" % _fmt(float(cost_tree))
	chorus_buy.text   = "Buy (%s)" % _fmt(float(cost_chorus))

	backyard_buy.disabled = c < float(cost_back)
	tree_buy.disabled     = c < float(cost_tree)
	chorus_buy.disabled   = c < float(cost_chorus)

	# --- HABITATS ---
	var t_water: int   = int(gs.habitats.get("water", 0))
	var t_foliage: int = int(gs.habitats.get("foliage", 0))
	var t_shelter: int = int(gs.habitats.get("shelter", 0))

	water_tier.text   = "Tier: %d" % t_water
	foliage_tier.text = "Tier: %d" % t_foliage
	shelter_tier.text = "Tier: %d" % t_shelter

	var cost_water: int   = gs.habitat_cost("water")
	var cost_foliage: int = gs.habitat_cost("foliage")
	var cost_shelter: int = gs.habitat_cost("shelter")

	water_buy.text   = "Upgrade (%s)" % _fmt(float(cost_water))
	foliage_buy.text = "Upgrade (%s)" % _fmt(float(cost_foliage))
	shelter_buy.text = "Upgrade (%s)" % _fmt(float(cost_shelter))

	water_buy.disabled   = c < float(cost_water)
	foliage_buy.disabled = c < float(cost_foliage)
	shelter_buy.disabled = c < float(cost_shelter)

	click_button.text = "Click (+%s)" % _fmt(gs.base_click)

func _fmt(n: float) -> String:
	var absn: float = absf(n)
	var suffix: String = ""
	var div: float = 1.0
	if absn >= 1e12:
		suffix = "T"; div = 1e12
	elif absn >= 1e9:
		suffix = "B"; div = 1e9
	elif absn >= 1e6:
		suffix = "M"; div = 1e6
	elif absn >= 1e3:
		suffix = "k"; div = 1e3
	var val: float = n / div
	if div == 1.0:
		return "%d" % int(round(val))
	return "%.2f%s" % [val, suffix]
