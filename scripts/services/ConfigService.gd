# res://scripts/services/ConfigService.gd
extends Node
signal ready_signal
var is_ready: bool = false

const SAVE_PATH := "user://config.json"

var config: Dictionary = {
	"audio": {
		"master": 0.6  # default 60%
	}
}

func _ready() -> void:
	_load()
	is_ready = true
	ready_signal.emit()

func set_master_volume_linear(v: float) -> void:
	var audio: Dictionary = (config.get("audio", {}) as Dictionary)
	audio["master"] = clamp(v, 0.0, 1.0)
	config["audio"] = audio
	_save()

func get_master_volume_linear() -> float:
	var audio: Dictionary = (config.get("audio", {}) as Dictionary)
	return float(audio.get("master", 0.6))

func _save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(config, "  "))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var txt: String = f.get_as_text()

	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		config = (parsed as Dictionary)
		# Ensure required sections exist after load
		if not config.has("audio"):
			config["audio"] = {"master": 0.6}
		else:
			var audio: Dictionary = (config["audio"] as Dictionary)
			if not audio.has("master"):
				audio["master"] = 0.6
			config["audio"] = audio
	else:
		push_warning("[ConfigService] config.json not a Dictionary; keeping defaults.")
