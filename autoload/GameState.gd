extends Node
# (no class_name to avoid autoload name collision)

@onready var Config := get_node("/root/Config") as ConfigService
@onready var Unlocks := get_node("/root/Unlocks") as Unlocks

# ===== Core state =====
var croaks: float = 0.0
var lifetime_croaks: float = 0.0
var cps: float = 0.0
var base_click: float = 1.0
var rain_spirits: int = 0

# Typed: species_id -> count
var frogs: Dictionary[String, int] = {
	"backyard_coqui": 0,
	"tree_coqui": 0,
	"chorus_leader": 0
}

# Typed: lane -> tier
var habitats: Dictionary[String, int] = {
	"water": 0,
	"foliage": 0,
	"shelter": 0
}

# Content defs (JSON-like; keep as untyped Dictionary)
var species_defs: Dictionary = {
	"backyard_coqui": {"display":"Backyard Coqui","base_cps":0.2,"base_cost":10.0,"cost_r":1.15,"global_bonus":0.0,"global_cap":0.0},
	"tree_coqui":     {"display":"Tree Coqui","base_cps":0.35,"base_cost":50.0,"cost_r":1.18,"global_bonus":0.0,"global_cap":0.0},
	"chorus_leader":  {"display":"Chorus Leader","base_cps":0.05,"base_cost":250.0,"cost_r":1.20,"global_bonus":0.01,"global_cap":0.25}
}

var habitat_defs: Dictionary = {
	"water":   {"base_cost":100.0,"cost_r":1.25,"per_tier_mult":0.10},
	"foliage": {"base_cost":100.0,"cost_r":1.25,"per_tier_mult":0.10},
	"shelter": {"base_cost":100.0,"cost_r":1.25,"per_tier_mult":0.10}
}

# Timers & save
var _autosave_timer: Timer
var last_time_unix: int = 0

# --- Config knobs (can be overridden by JSON) ---
var cfg_base_click: float = 1.0
var cfg_diversity_k: float = 0.15        # M_diversity = 1 + k * sqrt(D)
var cfg_prestige_threshold: float = 1_000_000.0
var cfg_prestige_per_spirit: float = 0.10
var cfg_offline_cap_seconds: int = 3600 * 8
var cfg_unlocks_species: Dictionary = {}   # species_id -> rule dict
var cfg_unlocks_habitats: Dictionary = {}  # habitat_id -> rule dict

# Optional event knobs (not wired yet)
var cfg_rain_enabled: bool = false
var cfg_rain_interval_min: int = 300
var cfg_rain_interval_max: int = 360
var cfg_rain_duration: int = 60
var cfg_rain_mult: float = 1.5

func _ready() -> void:
	Config.load_config_json()
	load_game()
	recompute_cps()
	set_process(true)

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 15.0
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	add_child(_autosave_timer)
	_autosave_timer.timeout.connect(save_game)

func _process(delta: float) -> void:
	croaks += cps * delta
	lifetime_croaks += cps * delta

# ===== UI hooks =====
func click() -> void:
	croaks += Config.base_click

# ===== Config =====
func load_config_json(path_user: String = "user://coqui_config.json", path_res: String = "res://config/coqui_config.json") -> void:
	# Prefer user overrides
	if FileAccess.file_exists(path_user):
		_apply_config_file(path_user)
		return

	# Else, if a project default exists, apply it and copy to user://
	if FileAccess.file_exists(path_res):
		_apply_config_file(path_res)
		var fin: FileAccess = FileAccess.open(path_res, FileAccess.READ)
		var fout: FileAccess = FileAccess.open(path_user, FileAccess.WRITE)
		if fin and fout:
			fout.store_string(fin.get_as_text())
			fout.close()
			fin.close()
		return

	# Fallback: generate from hardcoded defaults and write to user://
	var default_cfg: Dictionary = _make_default_config()
	apply_config(default_cfg)
	var fout2: FileAccess = FileAccess.open(path_user, FileAccess.WRITE)
	if fout2:
		fout2.store_string(JSON.stringify(default_cfg, "\t"))
		fout2.close()

func _apply_config_file(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f:
		var txt: String = f.get_as_text()
		f.close()
		var res: Variant = JSON.parse_string(txt)
		if res is Dictionary:
			apply_config(res as Dictionary)

func apply_config(cfg: Dictionary) -> void:
	# Clicks
	if cfg.has("click"):
		var clk: Dictionary = cfg["click"] as Dictionary
		if clk.has("base_click"):
			cfg_base_click = float(clk["base_click"])
			base_click = cfg_base_click

	# Species
	if cfg.has("species"):
		var sp: Dictionary = cfg["species"] as Dictionary
		for sid in sp.keys():
			if not species_defs.has(sid):
				continue
			var sdef: Dictionary = species_defs[sid] as Dictionary
			var src: Dictionary = sp[sid] as Dictionary
			if src.has("base_cps"):      sdef["base_cps"]  = float(src["base_cps"])
			if src.has("base_cost"):     sdef["base_cost"] = float(src["base_cost"])
			if src.has("r"):             sdef["cost_r"]    = float(src["r"])
			if src.has("global_bonus"):  sdef["global_bonus"] = float(src["global_bonus"])
			if src.has("global_cap"):    sdef["global_cap"]   = float(src["global_cap"])

	# Habitats
	if cfg.has("habitats"):
		var hb: Dictionary = cfg["habitats"] as Dictionary
		for lane in hb.keys():
			if not habitat_defs.has(lane):
				continue
			var hdef: Dictionary = habitat_defs[lane] as Dictionary
			var src2: Dictionary = hb[lane] as Dictionary
			if src2.has("per_tier_mult"): hdef["per_tier_mult"] = float(src2["per_tier_mult"])
			if src2.has("base_cost"):     hdef["base_cost"]     = float(src2["base_cost"])
			if src2.has("r"):             hdef["cost_r"]        = float(src2["r"])

	# Diversity
	if cfg.has("diversity"):
		var dv: Dictionary = cfg["diversity"] as Dictionary
		if dv.has("k"):
			cfg_diversity_k = float(dv["k"])

	# Prestige
	if cfg.has("prestige"):
		var pr: Dictionary = cfg["prestige"] as Dictionary
		if pr.has("threshold"):       cfg_prestige_threshold = float(pr["threshold"])
		if pr.has("per_spirit_mult"): cfg_prestige_per_spirit = float(pr["per_spirit_mult"])

	# Events (optional)
	if cfg.has("events"):
		var ev: Dictionary = cfg["events"] as Dictionary
		if ev.has("rain_enabled"):    cfg_rain_enabled      = bool(ev["rain_enabled"])
		if ev.has("interval_min"):    cfg_rain_interval_min = int(ev["interval_min"])
		if ev.has("interval_max"):    cfg_rain_interval_max = int(ev["interval_max"])
		if ev.has("duration"):        cfg_rain_duration     = int(ev["duration"])
		if ev.has("mult"):            cfg_rain_mult         = float(ev["mult"])

	# Offline
	if cfg.has("offline"):
		var off: Dictionary = cfg["offline"] as Dictionary
		if off.has("cap_seconds"):
			cfg_offline_cap_seconds = int(off["cap_seconds"])
			
	# Unlocks
	if cfg.has("unlocks"):
		var un: Dictionary = cfg["unlocks"] as Dictionary
		if un.has("species"):
			cfg_unlocks_species = (un["species"] as Dictionary).duplicate(true)
		if un.has("habitats"):
			cfg_unlocks_habitats = (un["habitats"] as Dictionary).duplicate(true)


func _make_default_config() -> Dictionary:
	return {
		"click": { "base_click": 1.0, "click_scales_with_cps": false, "click_cps_factor": 0.01 },
		"species": {
			"backyard_coqui": { "base_cps": 0.2,  "base_cost": 10,  "r": 1.15 },
			"tree_coqui":     { "base_cps": 0.35, "base_cost": 50,  "r": 1.18 },
			"chorus_leader":  { "base_cps": 0.05, "base_cost": 250, "r": 1.20, "global_bonus": 0.01, "global_cap": 0.25 }
		},
		"habitats": {
			"water":   { "per_tier_mult": 0.10, "base_cost": 100, "r": 1.25 },
			"foliage": { "per_tier_mult": 0.10, "base_cost": 100, "r": 1.25 },
			"shelter": { "per_tier_mult": 0.10, "base_cost": 100, "r": 1.25 }
		},
		"diversity": { "k": 0.15 },
		"prestige":  { "threshold": 1000000, "per_spirit_mult": 0.10, "gain_exp": 0.5 },
		"events":    { "rain_enabled": false, "interval_min": 300, "interval_max": 360, "duration": 60, "mult": 1.5 },
		"offline":   { "cap_seconds": 28800 }
	}

# ===== Costs =====
func frog_cost(species: String) -> int:
	var n: int = frogs.get(species, 0)
	var defn: Dictionary = Config.species_defs[species] as Dictionary
	return int(ceil(float(defn["base_cost"]) * pow(float(defn["cost_r"]), n)))

func habitat_cost(lane: String) -> int:
	var tier: int = habitats.get(lane, 0)
	var defn: Dictionary = Config.habitat_defs[lane] as Dictionary
	return int(ceil(float(defn["base_cost"]) * pow(float(defn["cost_r"]), tier)))

# ===== Purchasing =====
func can_buy_frog(species: String) -> bool:
	return croaks >= frog_cost(species)

func buy_frog(species: String) -> bool:
	if not Unlocks.is_unlocked(species, frogs, habitats, get_diversity(), lifetime_croaks):
		return false
	var cost := frog_cost(species)
	if croaks < cost: return false
	croaks -= cost
	frogs[species] = frogs.get(species, 0) + 1
	recompute_cps()
	return true

func can_buy_habitat(lane: String) -> bool:
	return croaks >= habitat_cost(lane)

func buy_habitat(lane: String) -> bool:
	if not is_habitat_unlocked(lane):
		return false
	var cost: int = habitat_cost(lane)
	if croaks < cost:
		return false
	croaks -= cost
	habitats[lane] = habitats.get(lane, 0) + 1
	recompute_cps()
	return true


# ===== Production math =====
func get_diversity() -> int:
	var d: int = 0
	for s in species_defs.keys():
		if frogs.get(s, 0) > 0:
			d += 1
	return d

func recompute_cps() -> void:
	var base_sum := 0.0
	var global_bonus := 0.0

	# chorus global (if present in config)
	if Config.species_defs.has("chorus_leader"):
		var chorus_def: Dictionary = Config.species_defs["chorus_leader"] as Dictionary
		var per := float(chorus_def.get("global_bonus", 0.0))
		var cap := float(chorus_def.get("global_cap", 0.0))
		global_bonus = min(per * float(frogs.get("chorus_leader", 0)), cap)

	for s in Config.species_defs.keys():
		var count: int = frogs.get(s, 0)
		if count <= 0: continue
		var sdef: Dictionary = Config.species_defs[s] as Dictionary
		base_sum += float(sdef["base_cps"]) * float(count)

	var w := Config.habitat_defs["water"] as Dictionary
	var f := Config.habitat_defs["foliage"] as Dictionary
	var sh := Config.habitat_defs["shelter"] as Dictionary
	var m_water   := 1.0 + float(w["per_tier_mult"])  * float(habitats["water"])
	var m_foliage := 1.0 + float(f["per_tier_mult"])  * float(habitats["foliage"])
	var m_shelter := 1.0 + float(sh["per_tier_mult"]) * float(habitats["shelter"])

	var diversity := get_diversity()
	var m_diversity := 1.0 + Config.k_diversity * sqrt(float(diversity))
	var m_prestige  := 1.0 + Config.prestige_per_spirit * float(rain_spirits)
	var m_global    := 1.0 + global_bonus

	cps = base_sum * m_water * m_foliage * m_shelter * m_diversity * m_prestige * m_global

# ===== Prestige =====
func can_prestige() -> bool:
	return lifetime_croaks >= Config.prestige_threshold

func prestige_gain() -> int:
	if not can_prestige():
		return 0
	return int(floor(pow(lifetime_croaks / 1_000_000.0, 0.5)))

func do_prestige() -> void:
	if not can_prestige():
		return
	rain_spirits += prestige_gain()
	# reset
	croaks = 0.0
	lifetime_croaks = 0.0
	for s in frogs.keys():
		frogs[s] = 0
	for l in habitats.keys():
		habitats[l] = 0
	recompute_cps()
	save_game()

func is_species_unlocked(id: String) -> bool:
	if id == "backyard_coqui":
		return true
	if not cfg_unlocks_species.has(id):
		return true
	var rule: Dictionary = cfg_unlocks_species[id] as Dictionary

	# habitats gate
	if rule.has("habitats"):
		var need: Dictionary = rule["habitats"] as Dictionary
		for lane in need.keys():
			if habitats.get(String(lane), 0) < int(need[lane]):
				return false

	# diversity gate
	if rule.has("diversity") and get_diversity() < int(rule["diversity"]):
		return false

	# lifetime croaks gate
	if rule.has("lifetime") and lifetime_croaks < float(rule["lifetime"]):
		return false

	# frog counts gate
	if rule.has("frogs"):
		var fneed: Dictionary = rule["frogs"] as Dictionary
		for sid in fneed.keys():
			if frogs.get(String(sid), 0) < int(fneed[sid]):
				return false

	return true


func species_unlock_hint(id: String) -> String:
	if id == "backyard_coqui":
		return ""
	if not cfg_unlocks_species.has(id):
		return ""
	var rule: Dictionary = cfg_unlocks_species[id] as Dictionary
	var parts: Array[String] = []

	if rule.has("habitats"):
		var lane_txt: Array[String] = []
		var need: Dictionary = rule["habitats"] as Dictionary
		for lane in need.keys():
			lane_txt.append("%s %s" % [String(lane).capitalize(), _roman(int(need[lane]))])
		parts.append("Reach " + ", ".join(lane_txt))
	if rule.has("diversity"):
		parts.append("Diversity %d" % int(rule["diversity"]))
	if rule.has("lifetime"):
		parts.append("Lifetime %.0f croaks" % float(rule["lifetime"]))
	if rule.has("frogs"):
		var fneed: Dictionary = rule["frogs"] as Dictionary
		for sid in fneed.keys():
			parts.append("%s x%d" % [String(sid).capitalize().replace("_"," "), int(fneed[sid])])

	return "Locked — " + "; ".join(parts)

func _roman(n: int) -> String:
	var map := {1000:"M",900:"CM",500:"D",400:"CD",100:"C",90:"XC",50:"L",40:"XL",10:"X",9:"IX",5:"V",4:"IV",1:"I"}
	var s := ""; var x := n
	for k in map.keys():
		var v: int = int(k)
		while x >= v:
			s += map[k]; x -= v
	return s

# Habitats
func is_habitat_unlocked(id: String) -> bool:
	# Default: unlocked if no rule provided
	if not cfg_unlocks_habitats.has(id):
		return true
	var rule: Dictionary = cfg_unlocks_habitats[id] as Dictionary

	# Gate by CPS threshold
	if rule.has("cps"):
		if cps < float(rule["cps"]):
			return false

	# Optional gates you may add later:
	# lifetime croaks
	if rule.has("lifetime"):
		if lifetime_croaks < float(rule["lifetime"]):
			return false
	# diversity
	if rule.has("diversity"):
		if get_diversity() < int(rule["diversity"]):
			return false

	return true

func habitat_unlock_hint(id: String) -> String:
	if not cfg_unlocks_habitats.has(id):
		return ""
	var rule: Dictionary = cfg_unlocks_habitats[id] as Dictionary
	var parts: Array[String] = []

	if rule.has("cps"):
		parts.append("Unlocks at %s CPS" % _fmt_float(float(rule["cps"])))
	if rule.has("diversity"):
		parts.append("Diversity %d" % int(rule["diversity"]))
	if rule.has("lifetime"):
		parts.append("Lifetime %.0f croaks" % float(rule["lifetime"]))

	if parts.is_empty():
		return "Locked"
	return "Locked — " + "; ".join(parts)

# Helper function to format decimals
func _fmt_float(x: float) -> String:
	# drop trailing .0 for whole numbers, keep 1–2 decimals otherwise
	var i: int = int(x)
	if float(i) == x:
		return str(i)
	return "%.2f" % x

# ===== Save / Load (with typed-cast helpers) =====
func _load_into_int_map(src: Variant, target: Dictionary[String, int]) -> void:
	if not (src is Dictionary):
		return
	var d: Dictionary = src
	for k in d.keys():
		var key: String = String(k)
		var val_any: Variant = d[k]
		var val_int: int = int(val_any)
		target[key] = val_int

func save_game() -> void:
	var data: Dictionary = {
		"croaks": croaks,
		"lifetime": lifetime_croaks,
		"spirits": rain_spirits,
		"frogs": frogs,
		"habitats": habitats,
		"last_time_unix": Time.get_unix_time_from_system()
	}
	var f: FileAccess = FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.flush()
		f.close()

func load_game() -> void:
	var now: int = Time.get_unix_time_from_system()
	if FileAccess.file_exists("user://save.json"):
		var f: FileAccess = FileAccess.open("user://save.json", FileAccess.READ)
		if f:
			var txt: String = f.get_as_text()
			f.close()
			var res: Variant = JSON.parse_string(txt)
			if res is Dictionary:
				var d: Dictionary = res
				croaks = float(d.get("croaks", 0.0))
				lifetime_croaks = float(d.get("lifetime", 0.0))
				rain_spirits = int(d.get("spirits", 0))

				# Copy+cast into typed maps
				_load_into_int_map(d.get("frogs", null), frogs)
				_load_into_int_map(d.get("habitats", null), habitats)

				last_time_unix = int(d.get("last_time_unix", now))
				recompute_cps()

				# Offline progress (8h cap) without max/min Variant pitfalls
				var elapsed_raw: int = now - last_time_unix
				if elapsed_raw < 0:
					elapsed_raw = 0
				var capped: int = elapsed_raw
				var cap_limit: int = Config.offline_cap_seconds
				if capped > cap_limit:
					capped = cap_limit
				if capped > 0:
					croaks += cps * float(capped)
					lifetime_croaks += cps * float(capped)
				last_time_unix = now
	else:
		last_time_unix = now
		recompute_cps()

func hard_reset() -> void:
	croaks = 0.0
	lifetime_croaks = 0.0
	rain_spirits = 0
	for s in frogs.keys():
		frogs[s] = 0
	for l in habitats.keys():
		habitats[l] = 0
	last_time_unix = Time.get_unix_time_from_system()
	recompute_cps()
	save_game()
