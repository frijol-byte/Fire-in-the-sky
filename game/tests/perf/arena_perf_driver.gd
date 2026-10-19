class_name ArenaPerfDriver
extends Node
## Flies the flight arena on a script (cruise, boost, turn) and logs how long frames take, how
## many draw calls and triangles there are, then quits. Run it with `bash tools/perf_arena.sh`.
##
## Informative only: under Xvfb with the lavapipe software renderer the numbers say nothing about
## a real GPU. They do show when something gets much heavier than before.

## Frames to ignore at the start (shader compiles, the sky bake).
const WARMUP_FRAMES: int = 30
const MEASURED_FRAMES: int = 150
const BOOST_FROM_TICK: int = 60
const TURN_EVERY_TICKS: int = 90

var _frames: int = 0
var _times_ms: PackedFloat64Array = []
var _last_usec: int = 0
var _draw_calls: int = 0
var _primitives: int = 0
var _tick: int = 0
var _pilot_removed: bool = false

@onready var _arena: FlightTest = $"../Arena"


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_frames += 1
	if _frames > WARMUP_FRAMES:
		_times_ms.append(float(now - _last_usec) / 1000.0)
		_draw_calls = maxi(
			_draw_calls,
			int(
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				)
			)
		)
		_primitives = maxi(
			_primitives,
			int(
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
				)
			)
		)
	_last_usec = now
	if _times_ms.size() >= MEASURED_FRAMES:
		set_process(false)
		set_physics_process(false)
		_report()
		_quit_cleanly()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_arena):
		return
	var ship: Ship = _arena.ship
	if ship == null:
		return
	if not _pilot_removed:
		for child: Node in ship.get_children():
			if child is PlayerPilot:
				child.queue_free()
		_pilot_removed = true
	_tick += 1
	ship.controls = controls_for_tick(_tick)


## The scripted controls for physics tick `tick` (1-based): fly forward, boost after a while and
## change the turn direction every few seconds.
static func controls_for_tick(tick: int) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	controls.thrust = Vector3(0.0, 0.0, 1.0)
	controls.boost = tick >= BOOST_FROM_TICK
	var phase: int = (tick / TURN_EVERY_TICKS) % 4
	controls.rotate = Vector3(0.0, [0.0, 0.4, 0.0, -0.4][phase], 0.0)
	return controls


## Average, 95th percentile and worst of `times_ms`, plus the implied frame rate.
static func summarize(times_ms: PackedFloat64Array) -> Dictionary:
	if times_ms.is_empty():
		return {"avg_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0, "fps": 0.0}
	var sorted: PackedFloat64Array = times_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	for time: float in times_ms:
		total += time
	var average: float = total / times_ms.size()
	var p95_index: int = clampi(int(ceil(sorted.size() * 0.95)) - 1, 0, sorted.size() - 1)
	return {
		"avg_ms": average,
		"p95_ms": sorted[p95_index],
		"max_ms": sorted[sorted.size() - 1],
		"fps": 1000.0 / average if average > 0.0 else 0.0,
	}


## Frees the arena and lets a few frames pass before quitting: a sound still playing at exit is
## reported as a leaked resource (see `ShotDirector`).
func _quit_cleanly() -> void:
	_arena.queue_free()
	for _frame: int in 3:
		await get_tree().process_frame
	get_tree().quit()


func _report() -> void:
	var stats: Dictionary = summarize(_times_ms)
	print(
		(
			"PERF adapter=%s frames=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f fps=%.1f draw_calls=%d primitives=%d"
			% [
				RenderingServer.get_video_adapter_name(),
				_times_ms.size(),
				stats["avg_ms"],
				stats["p95_ms"],
				stats["max_ms"],
				stats["fps"],
				_draw_calls,
				_primitives,
			]
		)
	)
