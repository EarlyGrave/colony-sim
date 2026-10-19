class_name DebtState
extends RefCounted
## Per-prisoner essence debt (sentence measured in refined essence).

var total := 0
var paid := 0
var due_day := 0
## Auto-pay per day (0 = off).
var quota := 0
var despair := 0.0
## Refined paid toward the current installment (surplus carries over).
var period_paid := 0
## Interest added to the total so far.
var interest := 0
## Debt cleared, waiting for the player to choose stay/leave.
var pending_choice := false
## "", "stayed", "left", "escaped".
var outcome := ""


func remaining() -> int:
	return maxi(0, total - paid)
