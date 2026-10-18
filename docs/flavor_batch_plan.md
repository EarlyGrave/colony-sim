# Batch FL "Flavor + juice + polish" - plan (prompter)
Base: dev branch `claude/colony-sim-godot-4jftsm` AFTER optimization wave 2 is merged and green. One wave, 5 Sonnet workers, disjoint files; shared files (hud.gd, game.gd, event_bus.gd, effects_3d.gd) only in `# region <agent>`. Report: `docs/agents/<agent>/FL-report.md` (<= 30 lines). No push. All in-game text English (Warden voice: dry, bureaucratic, never real groups, no slurs, no gore). Source: `docs/scout/flavor_pass.md`.

## Design decisions (log in DECISIONS.md as "decided without owner, review")
- **Picker is view-side** (`view/flavor_picker.gd`, RefCounted, no Node): flavor is cosmetic, never read by the sim, never in `state_hash`/saves, so goldens stay byte-identical. It does NOT touch `sim.rng` (that would shift every golden). Seed = `hash([tick, trigger_key, subject_id])` fed to its own local `RandomNumberGenerator`: same sim run -> same lines, no `randi()/randf()/Time`.
- Exception: per-colonist counters (F3) are sim-side facts (`sim/colonists/colonist_record.gd`, RefCounted), saved with colonists but EXCLUDED from `state_hash`; nicknames/rap sheets are derived view-side from counters + colonist id.
- Flavor never changes balance. Thresholds for nicknames/commendations live in `data/balance.json`.

## F1 text bank + picker
Owns `data/flavor.json`, `view/flavor_picker.gd`, `autoload/`-free (loaded by `Defs`-style static `FlavorPicker.load()`), `tests/test_flavor.gd`, `docs/sim_contract.md` row.
- `flavor.json`: top keys `feed`, `pa`, `barks`, `nicknames`, `rapsheet`, `epitaph`, `tips`, `splat`; each leaf = array of strings. API: `pick(key:String, ctx:Dictionary) -> String`, `has_key(key)`, `all_keys()`. Placeholders `{who} {victim} {enemy} {n} {cause}` resolved from ctx; unknown placeholder -> empty string + test failure in data check.
- No-repeat ring: last N=4 lines per key (or len-1 if fewer); ring is picker state, not saved.
- Seed ~15 lines per feed/pa key, ~6 per other (F2/F3 may only append lines to their own subtree).
- Accept: every line <= 70 chars and no unresolved `{}` after resolving with a full ctx (assert over ALL lines); every key referenced from `view/*.gd` via `FlavorPicker.K_*` constants exists (grep test); same seed twice -> identical 200-pick sequence; no repeat within any window of 4 picks for keys with >= 5 lines (1000 picks); 0 script errors.

## F2 event feed + Warden PA
Owns `view/feed_ticker.gd`, `view/pa_banner.gd`, `view/hud.gd` (region F2), `tests/test_feed.gd`. Uses F1 API (stub `pick` returning key if F1 not merged).
- Kill feed: corner ticker, max 3 lines, each fades after 6 s (tweens, no per-frame polling); on `enemy_killed`/`colonist_died`/`colonist_downed`/`building_destroyed` + cause (turret, melee, burn, acid, collapse, bleed_out, starvation, from sim facts already on the bus or `sim.threats` last-hit data; if missing, fall back to cause `generic`). Keys `feed.<enemy_id>.<cause>`, fallback `feed.<enemy_id>.generic`, then `feed.generic`.
- PA banner (top-centre, 2.5 s, not blocking input, mouse_filter IGNORE, below tutorial card) on `wave_started`, `wave_incoming`, `crisis_started`, `research_completed`, `colonist_downed`, `colonist_died`, `map_switched`/outpost lost (`Campaign` outpost destroyed signal; add `outpost_lost(id)` to event_bus in region F2 only if absent), and every 5th `day_started` quiet-day aside.
- Accept: simulated each signal -> exactly 1 feed/PA line, <= 70 chars; 10 kills in 1 s -> feed holds 3 lines, no leak (child count <= 3 after 7 s); banner rect fits 844x390 and does not intersect any control >= 64 px; PA queue max 2 (older dropped); 0 errors; frame cost with feed active <= 0.1 ms (view_bench).

## F3 inmate record: nicknames, barks, rap sheets, commendations
Owns `sim/colonists/colonist_record.gd`, `view/panels/sections/record_section.gd`, `view/bark_layer.gd`, `data/names.json` (append `rapsheet`), `data/milestones.json` (append `commendations`), `tests/test_record.gd`. Edits `colonist_section.gd` only to mount the new section (1 line, region F3).
- Counters per colonist: kills, downs, hauled, refined, waves_survived; updated from bus in `ColonistRecord`; serialised with the colonist; not in `state_hash`.
- Nickname: first stat crossing threshold (balance.json `flavor.nick_*`) earns "First 'Nick' Last" from `nicknames.<stat>`; permanent once earned.
- Rap sheet card in colonist panel: Crime / Sentence / Complaint / Last words, composed from lists, seeded by colonist id (stable across reloads).
- Barks: bubble 2 s above colonist, per-colonist cooldown 90 s (game time), states working/fleeing/hungry/refining/wave_won; max 2 bubbles visible.
- Commendations: >= 5 (Participation Ribbon, Clean Hands, Mass Disappointment, Debt Enthusiast, Toast Master) fire a letter toast once, saved in meta.
- Accept: counters equal bus facts over a 3000-tick scenario (seed 2); state_hash identical with/without record counters present; rap sheet same string for same id, differs for >= 90% of 20 ids; bark cooldown test (2 triggers in 89 s -> 1 bark); save/load round-trips counters and nickname; goldens unchanged.

## F4 visual juice (perf-safe)
Owns `view/effects_3d.gd` (region F4), `view/juice_fx.gd`, `data/fx.json`, `tests/test_juice.gd`.
- Death burst: 8-12 particles tinted by `enemies.json` color, 0.4 s, brute 2x count + 2 px shake; pooled MultiMesh, hard cap 64 live particles.
- Splat decals: spitter/crawler deaths + acid hits leave a flat quad, 20 s fade, pool 40, colour lerps grey->sickly green by contamination level (ramp in fx.json).
- Refinery sludge drips: rate scales with waste output, max 3 drops per active refinery, only on-screen refineries.
- Rare floating text "AUDITED" (5% of structure hits, seeded cosmetic RNG, not sim.rng), 1 label pooled max 3.
- Accept: no per-event node allocation after warm-up (pool sizes constant over 500 events); live particles <= 64, decals <= 40 asserted; splat colour differs at taint 0.1 vs 0.9 (G channel diff >= 0.15); `tools/view_bench.gd` shows added cost <= 0.3 ms/frame with 10 refineries + 30 enemies; goldens unchanged; fx disabled when `fx.enabled=false`.

## F5 polish backlog + web smoke
Owns `view/panels/expedition_panel.gd`, `view/panels/new_game_dialog.gd`, `view/radial_menu.gd`, `view/belt_layer.gd`, `view/hud.gd` (region F5: layout only), `tests/test_polish_fl.gd`.
- Recall button (>= 64 px) per outpost row in expedition panel -> `Campaign.recall(id)`; disabled with reason text if recall returns false; row refreshes via `refresh()`.
- New-game dialog: inner margin >= 16 px on all sides, buttons >= 64 px, fits 844x390.
- Radial menu vs belt strip: ring clamps inside the viewport and never overlaps the belt build strip (rect scan: 0 px intersection at 844x390 and 2532x1170, press near each edge).
- If `tools/web_smoke.py` exists, run it (export Web, load page, play 600 ticks) and attach 2 screenshots (idle, feed+PA visible) under `docs/agents/f5/`; if absent, report "absent" and run the headless `tools/screenshot.gd` instead.
- Accept: recall test (outpost removed, crew back, 1 call); margin/overlap asserts above; 0 errors.

## Orchestrator after merge
Run full tests + goldens (must be unchanged), balance_report unchanged, one screenshot of feed+PA+splats, update PROGRESS/DECISIONS.
