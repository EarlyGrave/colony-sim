class_name PerkHooks
extends RefCounted
## Helpers for perk stat hooks (see sim/perks). Deterministic rounding without rng:
## the fractional remainder is carried per colonist and stat key.


## base * mult as an int; the remainder is carried in c.perk_carry[key].
## Without a colonist (or without a bonus) this is a plain roundi().
static func scaled(c: Colonist, key: String, base: float, mult: float) -> int:
	if c == null or is_equal_approx(mult, 1.0):
		return roundi(base)
	var v := base * mult + float(c.perk_carry.get(key, 0.0))
	var r := floori(v + 0.000001)
	c.perk_carry[key] = v - r
	return maxi(0, r)
