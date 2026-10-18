extends TestCase
## K3: audit chip text.


func test_chip_text() -> void:
	assert_eq(Hud.k3_chip_text(0), "Audit\ntoday")
	assert_eq(Hud.k3_chip_text(1), "Next audit\nin 1d")
	assert_eq(Hud.k3_chip_text(3), "Next audit\nin 3d")
