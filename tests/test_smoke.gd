extends TestCase


func test_event_bus_instances_are_isolated() -> void:
	var a := make_bus()
	var b := make_bus()
	var hits := [0]
	a.first_refine_done.connect(func(): hits[0] += 1)
	b.first_refine_done.emit()
	assert_eq(hits[0], 0)
	a.first_refine_done.emit()
	assert_eq(hits[0], 1)
