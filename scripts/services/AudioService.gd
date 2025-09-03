# res://scripts/services/AudioService.gd
extends Node
signal ready_signal
var is_ready: bool = false

func _ready() -> void:
	# Apply stored volume on boot
	var v: float = ConfigService.config.get("audio", {}).get("master", 0.6)
	set_master_volume_linear(v)
	is_ready = true
	ready_signal.emit()

func set_master_volume_linear(v: float) -> void:
	# v in [0..1] → dB
	var db := -80.0 if v <= 0.0 else 20.0 * log(v) / log(10.0)
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)
