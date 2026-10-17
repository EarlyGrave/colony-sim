class_name TestCase
extends RefCounted
## Base class for headless tests. Every method named `test_*` is a test.

const EventBusScript := preload("res://autoload/event_bus.gd")

var failures: Array[String] = []
var _owned_nodes: Array[Node] = []


func before_each() -> void:
	pass


func after_each() -> void:
	for n in _owned_nodes:
		if is_instance_valid(n):
			n.free()
	_owned_nodes.clear()


## A fresh, isolated event bus, freed automatically after the test.
func make_bus() -> Node:
	var bus: Node = EventBusScript.new()
	_owned_nodes.append(bus)
	return bus


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
