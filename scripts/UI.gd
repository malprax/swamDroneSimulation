# res://scripts/UI.gd
extends Panel

@onready var _hb: HBoxContainer = $HBoxContainer
@onready var _opt: OptionButton = $HBoxContainer/OptionButton

var _stats_label: Label
var _noise_slider: HSlider
var _stats_timer: Timer

# Button refs (created in scene or added manually)
var _btn_disable: Button
var _btn_restart: Button
var _btn_trail: Button
var _btn_stats: Button
var _btn_heatmap: Button
var _btn_demo: Button
var _chk_autohide: CheckBox

func _ready() -> void:
	# Build option button
	_opt.clear()
	_opt.add_item("Room1", 0)
	_opt.add_item("Room2", 1)
	_opt.add_item("Room3", 2)

	# Find existing buttons if present
	_btn_disable = _hb.get_node_or_null("ButtonDisable")
	_btn_restart = _hb.get_node_or_null("ButtonRestart")
	_btn_trail = _hb.get_node_or_null("ButtonTrail")

	# --- Add Toggle Stats & Toggle Heatmap buttons if missing ---
	if _hb.get_node_or_null("ButtonStats") == null:
		var b := Button.new()
		b.name = "ButtonStats"
		b.text = "Toggle Stats"
		_hb.add_child(b)
		_btn_stats = b
	else:
		_btn_stats = _hb.get_node("ButtonStats")

	if _hb.get_node_or_null("ButtonHeatmap") == null:
		var b2 := Button.new()
		b2.name = "ButtonHeatmap"
		b2.text = "Toggle Heatmap"
		_hb.add_child(b2)
		_btn_heatmap = b2
	else:
		_btn_heatmap = _hb.get_node("ButtonHeatmap")

	
	# Add Auto-Hide Heatmap checkbox if missing
	if _hb.get_node_or_null("ChkAutoHideHeatmap") == null:
		var cb := CheckBox.new()
		cb.name = "ChkAutoHideHeatmap"
		cb.text = "Auto-hide Heatmap on Hold"
		cb.button_pressed = true
		_hb.add_child(cb)
		_chk_autohide = cb
	else:
		_chk_autohide = _hb.get_node("ChkAutoHideHeatmap")

	# Add Run Demo Script button if missing
	if _hb.get_node_or_null("ButtonDemo") == null:
		var bd := Button.new()
		bd.name = "ButtonDemo"
		bd.text = "Run Demo Script"
		_hb.add_child(bd)
		_btn_demo = bd
	else:
		_btn_demo = _hb.get_node("ButtonDemo")
# ===== Noise slider =====
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size = Vector2(12, 0)
	_hb.add_child(sep)

	var noise_lbl: Label = Label.new()
	noise_lbl.text = "Noise:"
	_hb.add_child(noise_lbl)

	_noise_slider = HSlider.new()
	_noise_slider.name = "NoiseSlider"
	_noise_slider.min_value = 0.0
	_noise_slider.max_value = 1.0
	_noise_slider.step = 0.01
	_noise_slider.custom_minimum_size = Vector2(160, 0)
	_hb.add_child(_noise_slider)
	_noise_slider.value_changed.connect(_on_noise_changed)

	var sep2: HSeparator = HSeparator.new()
	sep2.custom_minimum_size = Vector2(12, 0)
	_hb.add_child(sep2)

	_stats_label = Label.new()
	_stats_label.text = "Stats: –"
	_hb.add_child(_stats_label)

	# Initialize from SimManager
	var sim: SimManager = _get_manager()
	if sim:
		var current_noise: float = sim.noise_level
		_noise_slider.value = current_noise

	# Timer for periodic stats update
	_stats_timer = Timer.new()
	_stats_timer.wait_time = 0.5
	_stats_timer.one_shot = false
	_stats_timer.autostart = true
	add_child(_stats_timer)
	_stats_timer.timeout.connect(_refresh_stats)

	# Wire up button signals (if they exist in scene)
	if _btn_disable:
		_btn_disable.pressed.connect(_on_disable_leader_pressed)
	if _btn_restart:
		_btn_restart.pressed.connect(_on_restart_pressed)
	if _btn_trail:
		_btn_trail.pressed.connect(_on_toggle_trail_pressed)
	if _btn_stats:
		_btn_stats.pressed.connect(_on_toggle_stats_pressed)
	if _btn_heatmap:
		_btn_heatmap.pressed.connect(_on_toggle_heatmap_pressed)
	if _btn_demo:
		_btn_demo.pressed.connect(_on_demo_pressed)
	if _chk_autohide:
		_chk_autohide.toggled.connect(_on_autohide_toggled)

# === Handlers bound to scene ===
func _on_option_button_item_selected(index: int) -> void:
	var root := _get_root()
	if root == null or not root.has_node("RedBox"):
		return
	var red := root.get_node("RedBox") as Node2D
	var names: Array[String] = ["Room1", "Room2", "Room3"]
	if index < 0 or index >= names.size():
		return
	var room_name: String = names[index]
	if not root.has_node(room_name):
		return
	var room := root.get_node(room_name) as Node2D
	red.global_position = room.global_position
	print("[LOG] RedBox moved to ", room_name)

func _on_disable_leader_pressed() -> void:
	var root := _get_root()
	if root and root.has_node("DroneSpawner"):
		var spawner := root.get_node("DroneSpawner")
		spawner.disable_leader()

func _on_restart_pressed() -> void:
	var root := _get_root()
	if root and root.has_node("DroneSpawner"):
		var spawner := root.get_node("DroneSpawner")
		spawner.spawn_drones()

func _on_toggle_trail_pressed() -> void:
	var trails: Array = get_tree().get_nodes_in_group("trails")
	if trails.is_empty():
		print("[LOG] No trails to toggle (spawn drones first).")
		return
	var any_visible: bool = false
	for t in trails:
		if t is Line2D and (t as Line2D).visible:
			any_visible = true
			break
	var new_vis: bool = not any_visible
	for t in trails:
		if t is Line2D:
			(t as Line2D).visible = new_vis
	print("[LOG] Trails visibility set to: ", new_vis)

# === Additional toggles ===
func _on_toggle_stats_pressed() -> void:
	var root := _get_root()
	if root and root.has_node("UI/StatsPanel"):
		var p := root.get_node("UI/StatsPanel")
		p.visible = not p.visible
		print("[LOG] StatsPanel visible: ", p.visible)
	else:
		print("[WARN] StatsPanel not found")

func _on_toggle_heatmap_pressed() -> void:
	var root := _get_root()
	if root and root.has_node("Heatmap"):
		var h := root.get_node("Heatmap")
		h.visible = not h.visible
		print("[LOG] Heatmap visible: ", h.visible)
	else:
		print("[WARN] Heatmap not found")

# === Noise slider handler ===
func _on_noise_changed(value: float) -> void:
	var sim: SimManager = _get_manager()
	if sim:
		sim.noise_level = clamp(value, 0.0, 1.0)

# === Refresh stats label ===
func _refresh_stats() -> void:
	var sim: SimManager = _get_manager()
	if sim == null:
		_stats_label.text = "Stats: (no manager)"
		return
	var avg: float = sim.avg_detection_time()
	var elapsed: float = sim.seconds_since_start()
	_stats_label.text = "Stats: total=%d | leader=%d | member=%d | avg=%.2fs | t=%.1fs" % [
		sim.total_detections, sim.leader_detections, sim.member_detections, avg, elapsed
	]

# === Helpers ===
func _get_root() -> Node:
	return get_tree().current_scene

func _get_manager() -> SimManager:
	var root := get_tree().current_scene
	if root and root.has_node("SimManager"):
		return root.get_node("SimManager") as SimManager
	return null

func _on_autohide_toggled(pressed: bool) -> void:
	var root := _get_root()
	if root and root.has_node("Heatmap"):
		var h = root.get_node("Heatmap")
		h.auto_hide_on_hold = pressed
		print("[LOG] Heatmap auto-hide:", pressed)

func _on_demo_pressed() -> void:
	var root := _get_root()
	if root == null:
		return
	# Atur skenario demo showcase
	if root.has_node("SimManager"):
		root.get_node("SimManager").noise_level = 0.5
	if root.has_node("DroneSpawner"):
		root.get_node("DroneSpawner").spawn_drones()
	# RedBox ke Room2
	if root.has_node("RedBox") and root.has_node("Room2"):
		var red := root.get_node("RedBox") as Node2D
		red.global_position = (root.get_node("Room2") as Node2D).global_position
	print("[DEMO] Demo scenario initialized")
