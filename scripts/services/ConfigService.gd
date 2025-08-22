# res://scripts/services/ConfigService.gd
extends Node
class_name ConfigService

var cfg: Dictionary = {}
var species_defs: Dictionary = {}
var habitat_defs: Dictionary = {}

# Exposed knobs for convenience
var k_diversity: float = 0.15
var prestige_threshold: float = 1_000_000.0
var prestige_per_spirit: float = 0.10
var offline_cap_seconds: int = 3600 * 8
var base_click: float = 1.0
var unlocks: Dictionary = {}

func _ready() -> void:
	load_config_json()

func load_config_json(path_user: String = "user://coqui_config.json", path_res: String = "res://config/coqui_config.json") -> void:
	if FileAccess.file_exists(path_user):
		_apply_file(path_user)
	elif FileAccess.file_exists(path_res):
		_apply_file(path_res)
		var fin := FileAccess.open(path_res, FileAccess.READ)
		var fout := FileAccess.open(path_user, FileAccess.WRITE)
		if fin and fout:
			fout.store_string(fin.get_as_text()); fout.close(); fin.close()
	else:
		# write defaults to user://
		var d := _defaults()
		cfg = d
		var f := FileAccess.open(path_user, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(d, "\t")); f.close()
	_apply_cfg(cfg)

func _apply_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f: return
	var parsed := JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		cfg = parsed
		_apply_cfg(cfg)

func _apply_cfg(c: Dictionary) -> void:
	# knobs
	if c.has("diversity"): k_diversity = float((c["diversity"] as Dictionary).get("k", k_diversity))
	if c.has("prestige"):
		var p := c["prestige"] as Dictionary
		prestige_threshold   = float(p.get("threshold", prestige_threshold))
		prestige_per_spirit  = float(p.get("per_spirit_mult", prestige_per_spirit))
	if c.has("offline"): offline_cap_seconds = int((c["offline"] as Dictionary).get("cap_seconds", offline_cap_seconds))
	if c.has("click"): base_click = float((c["click"] as Dictionary).get("base_click", base_click))
	# content
	if c.has("species"): species_defs = (c["species"] as Dictionary).duplicate(true)
	if c.has("habitats"): habitat_defs = (c["habitats"] as Dictionary).duplicate(true)
	if c.has("unlocks"): unlocks = (c["unlocks"] as Dictionary).duplicate(true)

func _defaults() -> Dictionary:
	return {
		"click": { "base_click": 1.0 },
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
		"prestige":  { "threshold": 1000000, "per_spirit_mult": 0.10 },
		"offline":   { "cap_seconds": 28800 },
		"unlocks": {
			"tree_coqui":    { "habitats": {"water":1,"foliage":1,"shelter":1} },
			"chorus_leader": { "diversity":2, "habitats":{"water":2} }
		}
	}
