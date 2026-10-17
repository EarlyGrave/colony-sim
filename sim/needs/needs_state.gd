class_name NeedsState
extends RefCounted
## Per-colonist needs, both 0..1 (1 = full / rested).

var food := 1.0
var rest := 1.0
## No eat / sleep decision before this tick (retry cooldown).
var next_check := 0
## Ticks spent at zero food since the last starvation injury.
var starve_t := 0
