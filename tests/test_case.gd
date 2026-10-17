class_name TestCase
extends RefCounted
## Base class for headless tests. Every method named `test_*` is a test.

const EventBusScript := preload("res://autoload/event_bus.gd")

var failures: Array[String] = []
var _owned_nodes: Array[Node] = []
var _sims: Array[Simulation] = []


func before_each() -> void:
	pass


func after_each() -> void:
	for s in _sims:
		s.dispose()
	_sims.clear()
	for n in _owned_nodes:
		if is_instance_valid(n):
			n.free()
	_owned_nodes.clear()


## A fresh, isolated event bus, freed automatically after the test.
func make_bus() -> Node:
	var bus: Node = EventBusScript.new()
	_owned_nodes.append(bus)
	return bus


## Simulation on a fresh bus, disposed automatically after the test.
## `generate`: full new game; otherwise an empty w x h ground map.
func make_sim(seed_value: int, generate := true, w := 24, h := 24, defs: Defs = null) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), defs)
	if generate:
		sim.start_new_game()
	else:
		sim.start_empty(w, h)
	_sims.append(sim)
	return sim


## Defs with creature waves disabled, for tests about the economy.
static func peaceful_defs() -> Defs:
	var d := Defs.get_default().duplicate_defs()
	d.balance["threat"]["enabled"] = false
	return d


func fail(msg: String) -> void:
	failures.append(msg)


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		fail("expected true. " + msg)


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		fail("expected false. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("expected <%s> but got <%s>. %s" % [str(expected), str(actual), msg])


func assert_ne(actual: Variant, other: Variant, msg := "") -> void:
	if typeof(actual) == typeof(other) and actual == other:
		fail("expected values to differ, both <%s>. %s" % [str(actual), msg])


func assert_gt(a: float, b: float, msg := "") -> void:
	if not (a > b):
		fail("expected %s > %s. %s" % [str(a), str(b), msg])


func assert_lt(a: float, b: float, msg := "") -> void:
	if not (a < b):
		fail("expected %s < %s. %s" % [str(a), str(b), msg])


func assert_near(a: float, b: float, eps: float, msg := "") -> void:
	if absf(a - b) > eps:
		fail("expected %s ≈ %s (±%s). %s" % [str(a), str(b), str(eps), msg])
