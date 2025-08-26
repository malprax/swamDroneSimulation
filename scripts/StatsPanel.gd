# res://scripts/StatsPanel.gd
extends Panel

@export var bins: int = 10
@export var padding: int = 12

var _timer: Timer
var _cached: Array[float] = []

func _ready() -> void:
	self.custom_minimum_size = Vector2(560, 220)
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.autostart = true
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(func(): update())

func _get_times() -> Array[float]:
	var root := get_tree().current_scene
	if root and root.has_node("SimManager"):
		return root.get_node("SimManager").detection_times
	return []

func _draw() -> void:
	_cached = _get_times()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0,0,0,0.05))
	var rect := Rect2(padding, padding, size.x - padding*2, size.y - padding*2)
	draw_line(rect.position, rect.position + Vector2(0, rect.size.y), Color(0.6,0.6,0.6), 1.0)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.position + Vector2(rect.size.x, rect.size.y), Color(0.6,0.6,0.6), 1.0)

	if _cached.is_empty():
		draw_string(get_theme_default_font(), rect.position + Vector2(8, 18), "No data yet", HAlign.LEFT, -1, 14, Color(0.7,0.7,0.7))
		return

	var min_v := _cached.min()
	var max_v := _cached.max()
	if is_equal_approx(min_v, max_v):
		max_v += 1.0

	var bin_w := (max_v - min_v) / float(max(bins,1))
	var counts := PackedInt32Array()
	counts.resize(bins)
	for t in _cached:
		var idx := clamp(int((t - min_v) / bin_w), 0, bins-1)
		counts[idx] += 1
	var max_count := 1
	for c in counts: if c > max_count: max_count = c

	var bar_px_w := rect.size.x / float(bins)
	for i in range(bins):
		var h_ratio := float(counts[i]) / float(max_count)
		var h_px := h_ratio * (rect.size.y - 24.0)
		var x := rect.position.x + i * bar_px_w
		var y := rect.position.y + rect.size.y - h_px
		draw_rect(Rect2(Vector2(x+1, y), Vector2(bar_px_w-2, h_px)), Color(0.2,0.6,1.0,0.65))

	var sorted := _cached.duplicate()
	sorted.sort()
	var n := sorted.size()
	func q(p: float) -> float:
		var idx := clamp(int(round(p * (n-1))), 0, n-1)
		return sorted[idx]

	var q1 := q(0.25)
	var q2 := q(0.50)
	var q3 := q(0.75)
	var wmin := sorted[0]
	var wmax := sorted[n-1]

	func xmap(v: float) -> float:
		return rect.position.x + (v - min_v) / (max_v - min_v) * rect.size.x

	var y_mid := rect.position.y + rect.size.y + 4
	var box_y := y_mid
	var box_h := 10.0

	draw_line(Vector2(xmap(wmin), box_y + box_h/2), Vector2(xmap(q1), box_y + box_h/2), Color(0.3,0.3,0.3), 1.0)
	draw_line(Vector2(xmap(q3), box_y + box_h/2), Vector2(xmap(wmax), box_y + box_h/2), Color(0.3,0.3,0.3), 1.0)
	var box_rect := Rect2(Vector2(xmap(q1), box_y), Vector2(xmap(q3)-xmap(q1), box_h))
	draw_rect(box_rect, Color(1.0,0.85,0.2,0.25))
	draw_rect(box_rect, Color(0.8,0.6,0.0,0.9), false, 1.0)
	draw_line(Vector2(xmap(q2), box_y), Vector2(xmap(q2), box_y + box_h), Color(1.0,0.2,0.2), 2.0)
