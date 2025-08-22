extends Control

# --- references ---
@onready var gs := get_node("/root/GameState")  # autoload

# Containers
@onready var backyard_col: VBoxContainer = %BackyardCol
@onready var tree_col: VBoxContainer = %TreeCol
@onready var chorus_col: VBoxContainer = %ChorusCol
@onready var water_col:   VBoxContainer = %WaterCol
@onready var foliage_col: VBoxContainer = %FoliageCol
@onready var shelter_col: VBoxContainer = %ShelterCol

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

	# --- FROGS (with unlocks) ---
	var n_back: int   = int(gs.frogs.get("backyard_coqui", 0))
	var n_tree: int   = int(gs.frogs.get("tree_coqui", 0))
	var n_chorus: int = int(gs.frogs.get("chorus_leader", 0))

	# Unlock checks + hints
	var unlocked_tree: bool   = gs.is_species_unlocked("tree_coqui")
	var unlocked_chorus: bool = gs.is_species_unlocked("chorus_leader")
	var hint_tree: String     = gs.species_unlock_hint("tree_coqui")
	var hint_chorus: String   = gs.species_unlock_hint("chorus_leader")

	# Backyard (always unlocked)
	backyard_col.modulate = Color(1,1,1,1)
	backyard_count.text = "Owned: %d" % n_back
	var cost_back: int = gs.frog_cost("backyard_coqui")
	backyard_buy.text = "Buy (%s)" % _fmt(float(cost_back))
	backyard_buy.disabled = c < float(cost_back)

	# Tree Coqui
	if unlocked_tree:
		tree_col.modulate = Color(1,1,1,1)
		tree_count.text = "Owned: %d" % n_tree
		var cost_tree: int = gs.frog_cost("tree_coqui")
		tree_buy.text = "Buy (%s)" % _fmt(float(cost_tree))
		tree_buy.disabled = c < float(cost_tree)
		tree_buy.tooltip_text = ""
	else:
		tree_col.modulate = Color(1,1,1,0.5)  # gray out when locked
		tree_count.text = "Owned: —"
		tree_buy.text = hint_tree             # show requirement on the button
		tree_buy.disabled = true
		tree_buy.tooltip_text = hint_tree

	# Chorus Leader
	if unlocked_chorus:
		chorus_col.modulate = Color(1,1,1,1)
		chorus_count.text = "Owned: %d" % n_chorus
		var cost_chorus: int = gs.frog_cost("chorus_leader")
		chorus_buy.text = "Buy (%s)" % _fmt(float(cost_chorus))
		chorus_buy.disabled = c < float(cost_chorus)
		chorus_buy.tooltip_text = ""
	else:
		chorus_col.modulate = Color(1,1,1,0.5)
		chorus_count.text = "Owned: —"
		chorus_buy.text = hint_chorus
		chorus_buy.disabled = true
		chorus_buy.tooltip_text = hint_chorus


	# --- HABITATS (with unlocks) ---
	var t_water: int   = int(gs.habitats.get("water", 0))
	var t_foliage: int = int(gs.habitats.get("foliage", 0))
	var t_shelter: int = int(gs.habitats.get("shelter", 0))

	var unlocked_water: bool   = gs.is_habitat_unlocked("water")
	var unlocked_foliage: bool = gs.is_habitat_unlocked("foliage")
	var unlocked_shelter: bool = gs.is_habitat_unlocked("shelter")

	var hint_water: String   = gs.habitat_unlock_hint("water")
	var hint_foliage: String = gs.habitat_unlock_hint("foliage")
	var hint_shelter: String = gs.habitat_unlock_hint("shelter")

	# Water
	if unlocked_water:
		water_col.modulate = Color(1,1,1,1)
		water_tier.text    = "Tier: %d" % t_water
		var cost_water: int = gs.habitat_cost("water")
		water_buy.text     = "Upgrade (%s)" % _fmt(float(cost_water))
		water_buy.disabled = c < float(cost_water)
		water_buy.tooltip_text = ""
	else:
		water_col.modulate = Color(1,1,1,0.5)
		water_tier.text    = "Tier: —"
		water_buy.text     = hint_water
		water_buy.disabled = true
		water_buy.tooltip_text = hint_water

	# Foliage
	if unlocked_foliage:
		foliage_col.modulate = Color(1,1,1,1)
		foliage_tier.text    = "Tier: %d" % t_foliage
		var cost_foliage: int = gs.habitat_cost("foliage")
		foliage_buy.text     = "Upgrade (%s)" % _fmt(float(cost_foliage))
		foliage_buy.disabled = c < float(cost_foliage)
		foliage_buy.tooltip_text = ""
	else:
		foliage_col.modulate = Color(1,1,1,0.5)
		foliage_tier.text    = "Tier: —"
		foliage_buy.text     = hint_foliage
		foliage_buy.disabled = true
		foliage_buy.tooltip_text = hint_foliage

	# Shelter
	if unlocked_shelter:
		shelter_col.modulate = Color(1,1,1,1)
		shelter_tier.text    = "Tier: %d" % t_shelter
		var cost_shelter: int = gs.habitat_cost("shelter")
		shelter_buy.text     = "Upgrade (%s)" % _fmt(float(cost_shelter))
		shelter_buy.disabled = c < float(cost_shelter)
		shelter_buy.tooltip_text = ""
	else:
		shelter_col.modulate = Color(1,1,1,0.5)
		shelter_tier.text    = "Tier: —"
		shelter_buy.text     = hint_shelter
		shelter_buy.disabled = true
		shelter_buy.tooltip_text = hint_shelter

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
