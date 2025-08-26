extends Node
class_name SimManager
@export var noise_level: float = 0.0 : set = set_noise_level, get = get_noise_level
# ... (isi lengkap SimManager.gd seperti sebelumnya)
func set_noise_level(v: float) -> void:
	noise_level = clamp(v, 0.0, 1.0)

func get_noise_level() -> float:
	return noise_level

const CSV_PATH := "user://logs/detections.csv"

func broadcast_hold_and_return() -> void:
	if mission_locked: return
	mission_locked = true
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "drones", "start_hold_and_return")
