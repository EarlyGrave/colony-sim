# E1 report (stat core + resolver)
- New `sim/equipment/stat_block.gd`: KEYS/index consts, `make()`, `sum_into(packed, dict)`.
- `CombatSystem.resolve()` (static, pure) + `resolve_hit(att, def, dmg, kind)` in region E1. Flat first (minus flat_pen), then armour curve (armor*(1-pen_pct)), min 1. Zero armour/flat returns raw untouched (bit-identical to old numbers). Crit draws `sim.rng` only if crit_chance > 0.
- `hit_chance` adds `att[ACC]`; player attack and both enemy attack lines (threat_system 567, ~941) go through resolve_hit.
- Enemy: `att_stats`/`def_stats` filled from `def.armor`/`def.flat`; `data/enemies.json` has armor/flat = 0 on all creatures. Optional `dmg_type` key ("phys" default).
- `tools/combat_model.gd`: static `resolve`, `ttk(..., armor, flat)` (defaults 0 = old TTK).
- Tests: `tests/test_damage_formula.gd` (table 10 / 6.67 / 8.5 / 13.3 / min 1, model parity, StatBlock sum, armoured enemy). Quick suite + goldens green.
## Deviations / notes for E2-E4
- att/def vectors live in `CombatSystem` (`att_of(c)`, `def_of(c)`, `resum(c)`, `resum_count`), NOT on `CombatState`: storyteller `pending` holds colonist objects that `var_to_str` prints, so ANY new CombatState field changes goldens (verified with a dummy var). E2 should keep that rule or regen goldens.
- `resum_tick` on CombatState and the health_system role/perk fold-in were not done (perk `damage_taken` stays in apply_damage); left for E2/E4.
