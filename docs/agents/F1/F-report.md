# F1 report: flavor text bank + picker
- `data/flavor.json`: ~330 English lines, <= 70 chars resolved. Top keys feed, pa, barks, nicknames, rapsheet, epitaph, tips, gameover, splat.
- Keys are dotted paths: feed.generic, feed.colonist.{downed,generic,bleed_out,starvation,burn,acid,collapse,melee}, feed.building.destroyed, feed.<crawler|brute|spitter|burrower>.{generic,turret,melee}, pa.{wave_incoming,wave_started,wave_repelled,crisis_started,research_completed,colonist_downed,colonist_died,outpost_lost,quiet_day} (15 each), barks.{working,fleeing,idle,hungry,low_mood,refining,wave_won}, nicknames.{kills,downs,haul,refine}, rapsheet.{crime,sentence,complaint,last_words}, epitaph.{generic,bleed_out,starvation,killed}, tips, gameover.{pod_lost,all_dead}, splat.{audited,oof}.
- `view/flavor_picker.gd` (class FlavorPicker, RefCounted): `load_bank(path)` / `load_default()` (named load_bank because `load` shadows a global), `pick(key, ctx)`, `pick_first([keys], ctx)`, `has_key`, `all_keys`, `lines_of`, static `resolve`, `reset_ring`, `K_*` constants.
- ctx: `tick`, `id` (seed = hash([tick,key,id]), own local RNG, never sim.rng), placeholders who/victim/enemy/n/cause (missing -> empty). Unknown key -> "".
- No-repeat ring of min(4, len-1) per key, picker state only.
- F2 fallbacks: use `pick_first(["feed.<enemy>.<cause>","feed.<enemy>.generic","feed.generic"], ctx)`. Bank has feed.<enemy> only for generic/turret/melee, so other causes fall through.
- Tests `tests/test_flavor.gd` (8): top keys, length/placeholders, determinism, no repeat (1000 picks), K_* exist (plus grep of view/ for FlavorPicker.K_*).
- Shared edit: docs/sim_contract.md (new section + data-file table row). Goldens untouched; sharded suite 609 passed, 0 failed (x2).
