# F10 plan: onboarding + perf after the content sprint (no owner decisions, no balance, goldens unchanged)
Base: `git reset --hard claude/colony-sim-godot-4jftsm`. One wave, 3 workers, shared files only in `# region F10Wn`.
Do NOT touch: balance numbers, flags reg_enabled / fixation_enabled / wear_enabled, Remission, data/*.json gameplay values, goldens.
Report <=30 lines: `docs/agents/F10Wn/F10-report.md`. Merge order: W2 -> W1 -> W3 (W3 reuses W1's SeenFlags). Quick tests after each; full sharded suite once after W3 + `tools/web_smoke.py`.

## W1 Contextual hints for new systems
Existing mechanisms: `Hud.show_message()` (-> notification stack, game.gd HINTS pattern) and `letter_received`; hint density in `MetaStore.load_hint_density()` ("Full"/"New"/"Off").
Do: new `view/hint_director.gd` (class HintDirector, `# region F10W1` hook in view/game.gd `_ready` + a ~1 s poll; no sim changes, read-only polling of public state). New `view/seen_flags.gd` (static `seen(id)`, `mark(id)`, `reset()`, JSON in user://seen_flags.json, every read/write guarded, in-memory fallback). Texts live in `data/hints.json` (id -> text, English, <=70 chars, each tells the next tap):
- `gear_first`: first time any GearItem exists -> "You found gear. More > Gear to equip it."
- `gear_damaged`: first item with durability < 50% of max -> "Gear is worn. Gear screen > Repair (needs a workbench)."
- `alt_available`: first tick `petition.alt_available(p)` is true -> "Petition: a cheaper payment is open. See Petition."
- `path_choice`: Q14 choice posted (`quest_choice_posted` for the path quest, find id in data/quests*.json) -> "Choose your path. It changes waves and fees."
- `drone_raid`: first `metro_raid_started` -> "Drones from the Metropolis. Walls and turrets hold them."
Rules: each hint fires once per profile (SeenFlags); density "Off" -> none, "New" -> only gear_first/drone_raid; not while a tutorial step is active (`TutorialCard.current_step(sim) >= 0`); max one hint per 10 s (queue, drop stale). Save/load or replay must not re-fire a hint for state that already existed (poll compares against seen flags only, never mutates sim).
Files: view/hint_director.gd, view/seen_flags.gd, data/hints.json, view/game.gd `# region F10W1`, tests/test_f10_hints.gd. Not owned: hud.gd.
Tests: each trigger fires its text once (build sim, grant gear via public API / emit bus signals, step the director with fake clock); second call silent; Off / New density; text length <=70 for all entries; tutorial-active suppression; no sim hash change (state hash before/after poll equal).

## W2 Perf audit, late-game scenario
Do: `tools/perf_scenario.gd` `# region F10W2`: `late_game(sim, opts)` = metro enabled with a drone raid active, 10 inmates each equipped (6 slots, rare+ affixes, sockets), loot drops lying on the map (use gear_loot generator), 2-3 quests active (r4 lines), petition alt available, durability.wear_enabled forced ON for the bench only (via defs copy, not shared Defs). `tools/perf_bench.gd` new flag `--late=1` printing avg/p95 per bucket (threats, colonists, contamination, logistics, mutation, combat, total) and the delta vs budget. New `tests/test_f10_perf_late.gd`: runs the scenario (skipped by PERF_SKIP / PERF_SKIP_WALL like test_perf_budget), asserts `late` budgets x noise_margin. Add `"late": {...}` block to tests/perf_budget.json set to measured p95 x ~1.3 (not tighter than the existing totals; total <= 10 ms p95 contract stays).
Hot spots: fix only OBVIOUS, behaviour-neutral ones (cache a per-tick lookup, hoist a loop invariant, avoid per-tick array allocation) in the file the profile points to, each with a before/after number and goldens + quick tests green. Anything bigger -> listed in the report with file:line and estimated gain, not fixed.
Web estimate: report ms/tick desktop headless x web factor measured by `tools/web_smoke.py` (FPS at ?size=250) or, if no factor is recorded, state the ratio web_smoke yields at base load and apply it; add jsheap MB from web_smoke to the report.
Files: tools/perf_scenario.gd, tools/perf_bench.gd, tests/perf_budget.json, tests/test_f10_perf_late.gd, docs/gdd/10-tech/tools-measurement.md (one row), plus hot-spot fixes in sim/ only if obvious (name them in the report).
Accept: bench prints the table; test green; existing test_perf_budget numbers unchanged; goldens unchanged (`tools/make_golden.gd` NOT run).

## W3 "New" badges on toolbar / More menu
Do: `view/new_badge.gd` (small dot/"NEW" label child of a Button, mouse_filter ignore, <=28 px, no layout growth) in hud.gd `# region F10W3`: `Hud._f10_badges()` called from the existing panel-visibility refresh (hud.gd ~1589 area / `_panel_buttons`). Entries: `gear_screen` (first time a GearItem exists, same predicate as W1), `petition` alt (first `alt_available`), `orders` (Standing Orders, only while `reg_enabled` true), "More" button shows the badge while any entry inside it is new. Cleared when that panel opens (`toggle_panel`) and persisted via W1's `SeenFlags` ("badge.<panel>"). Respects hint density "Off" (no badges).
Files: view/new_badge.gd, view/hud.gd `# region F10W3` (3 small hooks only), tests/test_f10_badges.gd, tests/test_phone_layout.gd (append one test, new region at end).
Accept: badge appears once the predicate holds, not before; opening the panel clears it and it never returns after reload; flag-OFF regulations never badge; More button badge mirrors children; at 844x390 the badges do not overlap neighbours or enlarge any button (reuse the overlap scan in test_phone_layout.gd), buttons stay >=64 px.
Tests: test_f10_badges.gd (predicate on/off, clear on open, persistence via SeenFlags, density Off), phone layout test above.
