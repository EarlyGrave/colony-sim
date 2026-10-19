# PW2 report (W2 trait system)
- New sim/colonists/trait_system.gd (sim.traits): mod(c,stat), has_tag, has, grant (acquired_max 1), roll (weighted, excludes, block_only), acquired triggers: hardened on colonist_rescued, resigned (despair>=80 for 5 d), settled (30 d no break, lost on break).
- data/traits.json v2: 20 doc traits + 3 acquired, rarity/excludes/effects/desc; alias lazy->slow_burner. Weights/none_chance/max_traits live in traits.json (arrivals.json keys now unused).
- Generator: block first, fixed draws (1+max_traits). Hooks (region PW2): mood_base/break_chance/thought_<id> in mood, despair_mult (+despair_frozen tag) in debt _daily, hunger in needs, flee_threshold<=-1 skips alarm flee in job_system.
- Not consumed yet (data only): carry, xp_mult_*, hit, night/day work, mutation_risk, standing_gain, etc. (W1/W3/later).
- Goldens regenerated (INTENDED: generator rng stream changed by new trait draw); all 8 changed.
- Tests: tests/test_traits.gd (7 green); quick suite green.
