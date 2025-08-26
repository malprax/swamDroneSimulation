# res://scripts/Heatmap.gd
extends Node2D

@export var auto_hide_on_hold: bool = true
var _hidden_due_hold: bool = false
var _prev_visible: bool = true

@export var world_size: Vector2i = Vector2i(1280, 720)
@export var cell: int = 8
@export var refresh_sec: float = 0.2
@export var fade_per_tick: float = 0.0
@export var intensity_per_hit: float = 1.0
@export var max_intensity: float = 50.0

var _cols: int
var _rows: int
var _grid: PackedFloat32Array
var _img: Image
var _tex: ImageTexture
var _timer: Timer

func _ready() -> void:
	_cols = int(ceil(world_size.x / float(cell)))
	_rows = int(ceil(world_size.y / float(cell)))
	_grid = PackedFloat32Array()
	_grid.resize(_cols * _rows)
	_img = Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)

	_timer = Timer.new()
	_timer.wait_time = refresh_sec
	_timer.autostart = true
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(_refresh_texture)

	set_process(true)

func _process(_delta: float) -> void:
	# Auto-hide during hold via SimManager
	if auto_hide_on_hold:
		var root := get_tree().current_scene
		if root and root.has_node("SimManager"):
			var sim = root.get_node("SimManager")
			if sim.mission_locked and not _hidden_due_hold:
				_prev_visible = visible
				visible = false
				_hidden_due_hold = true
			elif not sim.mission_locked and _hidden_due_hold:
				visible = _prev_visible
				_hidden_due_hold = false
	
	var drones := get_tree().get_nodes_in_group("drones")
	for d in drones:
		if d is Node2D:
			var p: Vector2 = (d as Node2D).global_position
			var cx := clamp(int(p.x / cell), 0, _cols-1)
			var cy := clamp(int(p.y / cell), 0, _rows-1)
			var idx := cy * _cols + cx
			_grid[idx] = min(_grid[idx] + intensity_per_hit, max_intensity)

func _refresh_texture() -> void:
	if fade_per_tick > 0.0:
		for i in range(_grid.size()):
			_grid[i] = max(0.0, _grid[i] - fade_per_tick)

	_img.lock()
	for y in range(_rows):
		for x in range(_cols):
			var v := _grid[y * _cols + x] / max_intensity
			var col := _colormap(v)
			_img.set_pixel(x, y, col)
	_img.unlock()
	_tex.update(_img)
	update()

func _colormap(t: float) -> Color:
	t = clamp(t, 0.0, 1.0)
	if t < 0.33:
		return Color(0.2, 0.2 + t*2.2, 1.0 - t*3.0, t)
	elif t < 0.66:
		var u := (t - 0.33) / 0.33
		return Color(0.2 + u*0.6, 0.9, 0.1, 0.6 + 0.4*u)
	else:
		var u2 := (t - 0.66) / 0.34
		return Color(0.8 + 0.2*u2, 0.7 - 0.4*u2, 0.1, 1.0)

func _draw() -> void:
	if _tex:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(cell, cell))
		draw_texture(_tex, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
