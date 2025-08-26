# res://scripts/BatchRunner.gd
extends Node

@export var num_runs: int = 30
@export var noise_levels: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
@export var hold_wait_sec: float = 11.0   # tunggu sedikit di atas 10s hold

func _ready() -> void:
	# Jangan otomatis start jika tidak diinginkan; bisa dipanggil manual dari UI atau Remote.
	# call_deferred("_run_batch")
	pass

func run_batch() -> void:
	await _run_batch()

func _run_batch() -> void:
	var root := get_tree().current_scene
	if not root:
		push_error("No current scene")
		return

	if not root.has_node("DroneSpawner") or not root.has_node("SimManager") or not root.has_node("RedBox"):
		push_error("Missing nodes: DroneSpawner / SimManager / RedBox")
		return

	var spawner = root.get_node("DroneSpawner")
	var sim := root.get_node("SimManager") as SimManager
	var red = root.get_node("RedBox")

	var rooms: Array[String] = ["Room1","Room2","Room3"]

	for noise in noise_levels:
		for i in range(num_runs):
			# set kondisi
			if sim:
			sim.noise_level = noise

			# spawn ulang (reset mission)
			spawner.spawn_drones()

			# pilih room untuk redbox
			var room_name: String = rooms[randi() % rooms.size()]
			if root.has_node(room_name):
				var room := root.get_node(room_name) as Node2D
				red.global_position = room.global_position

			# (opsional) assign tiap drone ke room berbeda
			var drones := get_tree().get_nodes_in_group("drones")
			for j in range(drones.size()):
				var d = drones[j]
				if d and d.has_method("assign_room"):
					var rn: String = rooms[j % rooms.size()]
					var r := root.get_node(rn) as Node2D
					d.assign_room(r)

			# tunggu sampai hold terjadi (deteksi) -> mission_locked true
			await _wait_detection(sim)

			# tunggu sampai lewat masa hold (biar balik ke homebase)
			await get_tree().create_timer(hold_wait_sec).timeout

			print("[BATCH] noise=%.2f run=%d selesai" % [noise, i])

	print("[BATCH] Semua eksperimen selesai!")

func _wait_detection(sim) -> void:
	while not sim.mission_locked:
		await get_tree().create_timer(0.25).timeout
