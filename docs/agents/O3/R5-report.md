# O3 report: difficulty presets (prison sentences)
- data/presets.json: short_stay (wave 0.75, waste 0.8, debt 0.7, crate ore 40 + food 30), standard_term (all neutral), hard_time (1.3 / 1.25 / 1.3).
- StartOpts (region O3): preset_opts / merge_preset map presets to opts keys wave_mult, waste_mult, debt_mult, crate, hint_density. Neutral values emit no key, so standard_term opts == {} (identical to today).
- Sim reads: ThreatSystem.raid_points x wave_mult; ContaminationSystem.tick x waste_mult; DebtSystem._assign scales total after the rng draw by debt_mult (rng stream unchanged). hint_density is carried only (O2 consumes it).
- MetaState.preset (saved in meta.json) feeds make_opts(); Defs.presets loaded.
- view/panels/new_game_dialog.gd: three cards (88 px) with sentence + one-line numbers, Start button; game.gd (region O3) opens it from the "New Sentence" game-over button; meta_screen shows current sentence.
- Goldens: preset_short_stay / preset_standard_term / preset_hard_time (seed 2, raid_turrets script, 3000 ticks). Existing 5 goldens untouched and passing.
- tests/test_presets.gd: raid points wave 3 ladder >= 15% per step, waste scaling within 1%, debt scaling, dialog selects once per card, meta roundtrip.
- docs/sim_contract.md updated (presets.json row, opts keys).
