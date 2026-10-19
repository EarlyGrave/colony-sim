extends TestCase
## N3: Next Sentence flavor letters resolve for every sentence >= 2.


func test_every_sentence_resolves() -> void:
	for n in range(2, 12):
		var ls := NgFlavor.letters(n, {"name": "Vex"})
		assert_eq(ls.size(), 2)
		for l: Dictionary in ls:
			assert_true(str(l["title"]) != "" and str(l["text"]) != "")
			assert_false(str(l["text"]).contains("{"))
	assert_true(NgFlavor.letters(2)[0]["text"].contains("debt has been rolled over"))
	assert_true(NgFlavor.letters(3)[0]["text"].contains("never here"))
	assert_true(NgFlavor.letters(6)[0]["text"].contains("50%"))
	assert_true(NgFlavor.letters(2, {"name": "Vex"})[1]["text"].contains("Vex"))


func test_no_letters_on_fresh_sentence() -> void:
	assert_eq(NgFlavor.letters(1).size(), 0)
