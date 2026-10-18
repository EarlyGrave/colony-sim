# R1b report: golden replays
- 5 scenarios in `tests/golden/*.json` (peaceful_mining, raid_turrets, automation_chain, contamination_crisis, save_load_midgame), 3000 ticks, 30 hashes each (every 100 ticks) + per-part hashes.
- Format: `{seed, peaceful, opts, ticks, reload_at, hashes, parts, commands}`; logic in `tests/golden.gd`, test in `tests/test_golden.gd` (about 6-8 s total).
- Failure text: `golden <name>: first divergence at tick N (expected X got Y; differing parts: core, items, ...)`. Parts: core(state_hash), rng, items, colonists, buildings, belts, ledger, enemies, contamination, threats, storyteller, crises, contracts, debt, mutation, colonist_state.
- Regenerate (one command): `godot --headless --path . -s tools/make_golden.gd -- --regen [--only=name]`; refuses without `--regen`, prints how many hashes changed and the first tick. Documented in CLAUDE.md "Commands". Orchestrator: run it LAST after all merges, then commit tests/golden.
- Scenarios use only logged commands (no unlogged `buildings.place`), so replay == original. save_load_midgame does save->load at tick 1500 inside the run and checks state_hash equal.
- Verified: regen twice = 0 changed hashes; changing balance `start_items` makes the test fail with first-divergence text on all 5.
- Finding 1: `SaveGame.to_json` sorts dict keys, so `opts.crate` order changes after save/load and crate items spill differently (items drop on one cell). Goldens keep crate keys alphabetical; real saves with a multi-item crate in non-alphabetical order may differ after load.
- Finding 2: `*System.state_of()` creates state lazily; calling it from hashing code changes sim state. Golden parts read `col.mood/health/needs/perks` directly.
- Not touched: sim/, save_game.gd (replay decode duplicated in `Golden.decode_cmds`).
