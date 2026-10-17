class_name GameController
extends Node
## Owns the running Simulation, drives fixed ticks at the chosen speed and
## wires view + HUD. Player input becomes Simulation commands here.

const SPEEDS: Array[int] = [0, 1, 2, 3]
const MAX_TICKS_PER_FRAME := 40

var sim: Simulation
var speed := 1
var _accum := 0.0

@onready var world: WorldView = $World
@onready var camera: CameraController = $Camera


func _ready() -> void:
	camera.tapped.connect(_on_tapped)
	new_game(_initial_seed())


func _initial_seed() -> int:
	if OS.has_feature("web"):
		var s: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('seed')")
		if s != null and str(s).is_valid_int():
			return int(str(s))
	return int(Time.get_unix_time_from_system()) % 1000000


func new_game(seed_value: int) -> void:
	if sim:
		world.unbind()
		sim.dispose()
	sim = Simulation.new(seed_value, EventBus)
	sim.start_new_game()
	world.bind(sim)
	camera.world_size = world.world_size()
	camera.position = WorldView.cell_to_world(sim.map_center())
	camera.zoom = Vector2(1, 1)
	_accum = 0.0


func set_speed(s: int) -> void:
	speed = s


func _process(delta: float) -> void:
	if sim == null or speed == 0:
		return
	_accum += delta * Simulation.TICKS_PER_SECOND * speed
	var n := mini(int(_accum), MAX_TICKS_PER_FRAME)
	_accum -= int(_accum)
	for i in n:
		sim.step()


func _on_tapped(world_pos: Vector2) -> void:
	var cell := WorldView.world_to_cell(world_pos)
	if not sim.map.in_bounds(cell):
		return
	print("tap ", cell)
