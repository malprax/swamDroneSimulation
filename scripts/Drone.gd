# res://scripts/Drone.gd
extends CharacterBody2D

@export var speed: float = 160.0
@export var noise_base: float = 60.0   # px/s noise scale

var is_leader: bool = false
var assigned_room: Node2D = null
var found_box: bool = false
var leader_ref: Node = null
var home_ref: Node2D = null

var _trail: Line2D = null
var _sprite: Sprite2D = null
var _leader_label: Label = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const TRAIL_MAX_POINTS := 300
const TRAIL_MIN_DIST := 4.0
const LABEL_OFFSET := Vector2(-6, -26)

var _hold_in_progress: bool = false

func _ready() -> void:
	_rng.randomize()
	if not is_in_group("drones"):
		add_to_group("drones")

	var root := get_tree().current_scene
	if root and root.has_node("HomeBase"):
		home_ref = root.get_node("HomeBase")
	if assigned_room == null and home_ref:
		assigned_room = home_ref

	_trail = $Trail
	_sprite = $Sprite2D
	if _trail:
		_trail.add_to_group("trails")
		_trail.clear_points()

	# Leader label (top-level so it won't rotate)
	if _leader_label == null:
		_leader_label = Label.new()
		_leader_label.text = "L"
		_leader_label.set_as_top_level(true)
		_leader_label.modulate = Color(1, 0.85, 0.2, 1.0)  # gold
		add_child(_leader_label)

	_update_sprite_appearance()
	_update_leader_label_transform()

func set_leader(state: bool) -> void:
	is_leader = state
	_update_sprite_appearance()
	_update_leader_label_transform()

func _update_sprite_appearance() -> void:
	# Leader = gold, Member = cyan (tint the sprite without changing the PNG)
	if _sprite:
		if is_leader:
			_sprite.modulate = Color(1, 0.85, 0.2)  # gold
		else:
			_sprite.modulate = Color(0.2, 0.9, 1.0) # cyan
	if _leader_label:
		_leader_label.visible = is_leader

func _update_leader_label_transform() -> void:
	if _leader_label:
		_leader_label.global_position = global_position + LABEL_OFFSET
		_leader_label.rotation = 0.0

func assign_room(room: Node2D) -> void:
	assigned_room = room

func _physics_process(delta: float) -> void:
	if _hold_in_progress:
		_update_leader_label_transform()
		return
	if found_box:
		_update_leader_label_transform()
		return

	if assigned_room:
		var target := assigned_room.global_position
		var dir := (target - global_position)

		var root := get_tree().current_scene
		var noise_level_local: float = 0.0
		if root and root.has_node("SimManager"):
			var sim := root.get_node("SimManager") as SimManager
			if sim:
				noise_level_local = sim.noise_level

		var noise_vec := Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * noise_level_local * noise_base

		if dir.length() > 8.0:
			velocity = dir.normalized() * speed + noise_vec
			move_and_slide()
		else:
			velocity = Vector2.ZERO

	if _sprite and velocity.length() > 0.1:
		rotation = velocity.angle()

	_update_leader_label_transform()
	_update_trail()
	_check_redbox_proximity()

func _update_trail() -> void:
	if _trail == null or not _trail.visible:
		return
	var count := _trail.get_point_count()
	if count == 0:
		_trail.add_point(global_position)
	else:
		var last := _trail.get_point_position(count - 1)
		if last.distance_to(global_position) >= TRAIL_MIN_DIST:
			_trail.add_point(global_position)
			if _trail.get_point_count() > TRAIL_MAX_POINTS:
				_trail.remove_point(0)

func _check_redbox_proximity() -> void:
	if found_box or _hold_in_progress:
		return

	var root := get_tree().current_scene
	if root == null or not root.has_node("RedBox"):
		return
	var redbox := root.get_node("RedBox") as Node2D
	if redbox == null:
		return

	if global_position.distance_to(redbox.global_position) < 24.0:
		found_box = true

		# CSV log + stats + broadcast
		if root.has_node("SimManager"):
			var sim = root.get_node("SimManager")
			var t_sec: float = sim.seconds_since_start()
			sim.log_detection(name, is_leader, assigned_room.name, t_sec)
			sim.broadcast_hold_and_return()
		else:
			start_hold_and_return()

		if is_leader:
			print("[LOG] Leader found the red box in ", assigned_room.name)
		else:
			print("[LOG] Member ", name, " found the red box in ", assigned_room.name)

func start_hold_and_return() -> void:
	if _hold_in_progress:
		return
	_hold_in_progress = true
	velocity = Vector2.ZERO
	await get_tree().create_timer(10.0).timeout
	go_home()
	_hold_in_progress = false
	found_box = false

func go_home() -> void:
	if home_ref:
		assigned_room = home_ref
		print(name, " returning to HomeBase")
		if _trail:
			_trail.clear_points()
	_update_leader_label_transform()
