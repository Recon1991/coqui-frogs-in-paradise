extends Node
# (no class_name to avoid autoload name collision)

var gold: float = 0.0
var base_click: float = 1.0
var base_rate: float = 0.0
var rate: float = 0.0

# Typed dictionary: upgrade_id -> upgrade fields
var upgrades: Dictionary[String, Dictionary] = {
	"miner": {"level": 0, "base_cost": 10.0, "cost_factor": 1.15, "rate_per_level": 0.2},
	"drill": {"level": 0, "base_cost": 100.0, "cost_factor": 1.15, "rate_per_level": 2.0}
}

var last_time_unix: int = 0
var _autosave_timer: Timer

func _ready() -> void:
	load_game()
	recompute_rate()
	set_process(true)

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 15.0
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	add_child(_autosave_timer)
	_autosave_timer.timeout.connect(save_game)

func _process(delta: float) -> void:
	process_tick(delta)

func process_tick(delta: float) -> void:
	gold += rate * delta

func click() -> void:
	gold += base_click

func get_upgrade_cost(id: String) -> float:
	var data: Dictionary = upgrades[id]
	var level: int = int(data["level"])
	return float(data["base_cost"]) * pow(float(data["cost_factor"]), level)

func can_buy(id: String) -> bool:
	return gold >= get_upgrade_cost(id)

func buy(id: String) -> bool:
	var cost: float = get_upgrade_cost(id)
	if gold < cost:
		return false
	gold -= cost
	var lvl: int = int(upgrades[id]["level"]) + 1
	upgrades[id]["level"] = lvl
	recompute_rate()
	return true

func recompute_rate() -> void:
	rate = base_rate
	for id: String in upgrades.keys():
		var data: Dictionary = upgrades[id]
		rate += float(data["rate_per_level"]) * float(int(data["level"]))

func save_game() -> void:
	var data: Dictionary = {
		"gold": gold,
		"upgrades": upgrades,
		"last_time_unix": Time.get_unix_time_from_system()
	}
	var f: FileAccess = FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.flush()
		f.close()

func load_game() -> void:
	if FileAccess.file_exists("user://save.json"):
		var f: FileAccess = FileAccess.open("user://save.json", FileAccess.READ)
		if f:
			var txt: String = f.get_as_text()
			f.close()
			var res: Variant = JSON.parse_string(txt)
			if res is Dictionary:
				var d: Dictionary = res
				gold = float(d.get("gold", 0.0))
				var loaded_up: Variant = d.get("upgrades", upgrades)
				if loaded_up is Dictionary:
					upgrades = loaded_up as Dictionary[String, Dictionary]
				last_time_unix = int(d.get("last_time_unix", Time.get_unix_time_from_system()))
				recompute_rate()
				# Offline progress (avoid Variant math warnings by keeping ints explicit)
				var now: int = Time.get_unix_time_from_system()
				var elapsed_raw: int = now - last_time_unix
				var elapsed: int = elapsed_raw if elapsed_raw > 0 else 0
				var eight_hours: int = 3600 * 8
				var capped: int = elapsed if elapsed < eight_hours else eight_hours
				gold += rate * float(capped)
	else:
		last_time_unix = Time.get_unix_time_from_system()
		recompute_rate()

func hard_reset() -> void:
	gold = 0.0
	for id: String in upgrades.keys():
		upgrades[id]["level"] = 0
	recompute_rate()
	save_game()
