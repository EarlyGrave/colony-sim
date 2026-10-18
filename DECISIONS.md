# DECISIONS.md — significant decisions

Format: what was chosen · why · alternatives.

## D1. Godot 4.7.2 + GDScript instead of the TypeScript engine from the design doc
The design doc mentions a custom TypeScript engine + Tauri/Electron. The
kick-off prompt (newer, more specific) demands Godot + GDScript with a web
build. Followed the prompt. Web export still gives an itch.io / iPad-webview
path. Alternatives: custom TS engine (more work, no editor), C# (no web export).

## D2. Own minimal test runner instead of GUT
`tests/test_runner.gd` (≈60 lines) + `TestCase` base. No addon download,
no version drift with Godot 4.7, trivially headless, exit code for CI.
Alternative: GUT — richer but heavier and pinned to Godot versions.

## D3. Event bus: autoload script, injected instance
The prompt asks for an autoload with signals. Sim code receives the bus as a
constructor argument instead of referencing the `EventBus` singleton, so
tests can create isolated bus instances (`EventBusScript.new()`) and run
several simulations without cross-talk. The game passes the real autoload.

## D4. CI deploys only from `main`
Tests + web export run on every push to any branch; Pages deploy only from
`main` (as the prompt specifies). Work branches therefore don't change the
public build until merged.

## D5. Data in JSON, not .tres
`data/*.json` + `Defs` loader. Easy to edit/diff without the editor (we have
no GUI), trivially duplicated for test scenarios (`duplicate_defs()`).
Alternative: `.tres` Resources — typed, but awkward to author headless.

## D6. Jobs are generated on demand ("work givers"), not queued
Idle colonist asks providers in priority order (data/jobs.json), nearest
candidate wins; targets are reserved by string keys. No stale global queue to
keep in sync with the world. Alternative: persistent job queue — needs
invalidation on every world change.

## D7. Items are discrete stacks with a Ledger
One stack per cell, carried stacks, building buffers. Every creation /
destruction goes through `Ledger`, so "nothing appears or vanishes" is a
testable invariant (`count_world == produced - consumed`).

## D8. Buildings are walkable; deposits and rock are solid
Simplifies pathing (no footprint re-solving); workers stand on the building's
top-left cell. Deposits are mined from an adjacent cell.

## D9. "Склад" as an enemy target = the capsule
Storage is player-painted zones (per E3), zones have no HP. Enemies target
buildings by `threat_priority`: refinery (3) > capsule/HQ (2) > turret (1),
and turrets nearby / colonists in the open take precedence. The capsule
(starting HQ) is the shelter; losing it ends the game. Alternative: a storage
building with HP — would duplicate storage logic; can be added later.

## D10. Waves end on a timer; survivors retreat
A wave lasts `wave_duration_ticks`, then remaining creatures walk back to the
edge. Without this an undefended colony would be wiped on wave 1, which
contradicts "without turrets you fall on wave 2–3".

## D11. Wave balance targets (fixed-seed tests)
No turrets: colony falls on wave 2–3. Three static turrets: holds 3 waves,
falls on 4 (growth outpaces static defense = "needs intervention"). Player
rebuilding/adding turrets between waves: seed 1 survives 8 waves. Numbers in
`data/balance.json` "threat"; `tools/balance_report.gd` to re-check.

## D12. Repairs restore both HP and condition, cost nothing (for now)
Machines get repaired pre-emptively below 50% condition (data). Breakdowns
mostly happen under load during waves, when colonists hide. Later: repair
materials, maintenance rules.

## D13. Touch input: emulated mouse for one finger, raw touch for pinch
`emulate_mouse_from_touch=true` so HUD buttons work by touch and swallow
taps; world pan/tap uses (emulated) mouse in `_unhandled_input`, pinch uses
raw `InputEventScreenDrag`. Rect tools (zones, mining) use two taps instead of
drag, so dragging always pans.

## D14. UI scale from devicePixelRatio
Stretch mode `disabled`, `content_scale_factor = dpr * 0.85` (min 1). A fixed
1280×720 canvas_items base made buttons ~22 CSS px on a portrait phone.

## D15. Storyteller: one broken link at a time
Events (data/events.json) fire on a few daily checks with a chance, only when
the colony is "whole": nothing broken, nobody sick, no wave active or imminent.
Uses the single sim RNG (determinism preserved; balance re-tuned after).

## D16. Rules as data + JobSystem hooks
`data/rules.json` declares rules with defaults; `Simulation.rules` holds state,
`set_rule()` is the command. First rule implemented as a JobSystem override for
engineers. Later rules plug in the same way (or via a rule-evaluator system once
there are several).

## D17. Turret cost = refined essence only
Ties defense to refining (core dilemma) and fixes ore starvation found by the
balance bot.

## D18. Stress postponed, capsule stays the "storage" target
Owner decision, session 2.

## D19. Own generated pixel art instead of Kenney packs
Asset sites (kenney.nl, opengameart) are unreachable from the cloud session.
`tools/gen_art.py` (Python + PIL, deterministic) writes 16 px sprites to
`assets/sprites/`: terrain variants, colonists (normal / engineer / sick),
crawler, brute, turret base + rotating barrel, refinery, capsule, item icons,
mining marker. Drawn 2x with nearest filtering. Re-run the script after
editing it; commit the PNGs (and their `.import` files).
Cosmetic-only state (turret aim, hit flashes, death particles, smoke) lives in
`WorldView`, never in the sim.

## D20. Stage E9 is documentation only: contracts before code
`docs/ARCHITECTURE.md` (audit of the current code) and `docs/contracts/*.md`
(one file per domain: items/inventory, recipes/buildings, colonists/needs/jobs,
combat/weapons, research/events/save) are written before any E10+ code, in
parallel by small agents that each own one new file. No code or data touched in
E9, so the stage can never break tests. Alternative: write contracts inside the
code as comments — harder to review and to hand to parallel agents.

## D21. Keep existing item ids `refined_essence` / `waste`
The E9–E22 prompt names them `essence_refined` / `toxic_waste`. Renaming buys
nothing and would touch data, sim, view, tests and sprites. New content uses
the prompt's ids as given (`iron_ore`, `mech_parts`, `ammo_basic`…).

## D22. Agent reports live in `docs/agents/<agent>/<stage>-report*.md`
The architect's E9 work is split into topical reports (`E9-report-<topic>.md`)
because several agents wrote architect contracts in parallel. Significant
decisions are copied here with a link to the report.

## D23. Ammo: turrets consume `ammo_basic`, colonist firearms do not (E17)
From the prompt; recorded so combat/economy agents do not re-decide it. The
ammo supply line (hauling or conveyor to turrets) is the defense ↔ automation
link; `turret` becomes ammo-fed, `heavy_turret` is added.

## D24. Session 3 ran under an owner-set hard stop
Owner allowed ~13 minutes. Every agent got a wall-clock deadline and the rule
"a partial draft marked '(draft, unfinished)' beats nothing"; the orchestrator
reserved the last minutes for tests, commit, push and the handoff file.
Unfinished drafts are listed in `PROGRESS.md` and the handoff.

## D25. Contract reconciliation rulings 1–10 are binding
Owner delegated the call ("your code, decide"). All ten proposed rulings in
`docs/contracts/RECONCILIATION.md` are confirmed: `recipes` array, 9 canonical
skills with nullable skill, `storage_priority` 0..3 vs separate
`work_priority`, single `equip_item` command, weapons/armor as items with
stats in `weapons.json`/`armor.json` under the same id,
`order_attack(colonist_id, enemy_id)`, combat only injures and the health
model owns death, closed `Ledger.Reason` enum, full save coverage with
round-trip tests, frozen `story_event` args. D21 (keep `refined_essence` /
`waste`) is confirmed the same way. Next session applies these to the
contracts before writing E10 code.

## D20. Parallel agents with worktrees, merged by the lead
Features developed by Sonnet sub-agents in isolated git worktrees; the lead
merges, resolves conflicts (rules.json), runs the full suite and re-balances.
A game-designer agent reviews the build against the design pillars.

## D21. Balance pass after designer review
Contamination made heavier and waves more tied to refining (see PROGRESS).
Deconstruction reuses `building_destroyed` (does not end the game).

## D22. Owner answers for the RimWorld batch (session 2)
1. Stress/mood: basic version now (mood from needs/injuries/deaths, one breakdown type).
2. Research and trade: later.
3. Food: growing zones + stove with a simple recipe.
4. Enemies: creatures only for now; armed humans come later with factions.
5. Save/load: yes (autosave in browser + load).
6. Colonist death is permanent.

## D23. Perk system decisions (owner: "as you see fit, revise later")
Per-skill perk points (points = skill level − perks bought in that skill); skill scale 0–10,
starting levels 0–4; respec allowed for refined essence; active perks manual only;
total waste/contamination reduction from perks capped at 40%; passion affects xp only;
no vibration — letter + badge. Plan: docs/prompter_inbox.md §12.

## D24. Sub-streams of randomness allowed
New systems may use their own RandomNumberGenerator seeded deterministically from the sim seed
(e.g. contracts) so adding a system doesn't shift existing random streams. Still fully deterministic.

## Automation batch: owner answers (2026-10-18)
No power at start; purity 0.5/1/2 = speed only; base ores copper + iron + essence; nodes
invulnerable; one belt tier (1 item/cell, ~2 cells/s); splitters later; manual hauling always;
old saves marked incompatible (save version bump). Plan: docs/automation_batch_plan.md.

## Roadmap answers (2026-10-18)
- R1 "sim contract" runs as one worker inside the next wave, not a separate batch.
- Research cost: all three in different proportions — essence for big/science-advancing steps,
  part sets as tier unlocks (Satisfactory-style milestones), always bench time; later automated
  (AI chips work instead of colonists).
- Creatures may damage belts and machines.
- Expeditions = a real second playable map; factories for specific parts live on separate maps
  that yield specific elements.
- Target engine: undecided; engine comparison written for the owner (docs/engine_choice.md).
- Tutorial/onboarding (R5) comes AFTER expeditions (R4).

## Attention / threat generation (owner, 2026-10-18)
"Attention meter" = threat generation (aggro, MMO-style): every machine AND colonist has a
`threat` value (data-driven; machines by type/working state, colonists by activity/gear).
Creatures pick targets by threat (weighted by distance). Players may deliberately build
fortified high-threat "decoy/tank" structures to pull and absorb damage. Planned with the
"creatures damage machines" batch (R3).
- AI chips: benches/stations only for now, not mines (decided without owner, review).

## Expeditions design (decided without owner, review) — docs/expeditions_batch_plan.md
Campaign layer over several Simulations; home = map 0 (seed unchanged); only the active map
steps for real, unattended outposts run an analytic per-day autopilot (yield, buffer cap, raid
roll, "lost" state); outposts 96x96; biomes ash/crystal/swamp each yield a tier-2 element whose
part is crafted only at home; sling cargo with travel time; save v3 (v2 rejected).

## R3X integration (decided without owner, review)
- Threat model v2 is ON by default (`data/threat.json` enabled). Belts are targets (`base.belt`, one candidate per 8x8 region, value x sqrt(belt count) capped at `belt_scale_cap`); decoys use `Decoy.threat_now`; a busy chip building has threat x `state_mod.chip`.
- AI chip balance: a processor (smelter/assembler) without a chip runs at `unoperated_speed` 0.6 (colonist work adds steps on top); with a chip `processor_chip_speed` 1.0, waste x1.3, threat x2, upkeep and calibration unchanged. Benches keep chip_speed 0.8. Chips now matter for throughput, not only for freeing colonists.
- Ecology `starved_max` raised 4 -> 6 so clean-map early waves still threaten an undefended colony (test_waves intent: no turrets = dead by wave 2-3).
- Test hygiene: tests must not mutate `Defs.get_default()` (shared); test_ecology did, which shifted goldens when run after it.

## Combat control (owner, 2026-10-18)
Both: squads ("Wardens of the Line") are the main way, and single-inmate drafting stays (control one inmate directly).

## R5 Orientation tutorial (decided without owner, review)
- Tutorial progress is sim-side (`sim.tutorial`, opts `tutorial:true`); its state joins `state_hash` only in tutorial mode, so goldens are unchanged. Skips and `tutorial_ack` are recorded commands.
- Step 12 "release" completes by `tutorial_ack` (any tap). `forecast_revealed` fires at the first refine, long before step 9, so step 9 also accepts an ack (the view sends it when the forecast ticker is opened). Intake is acked when a colonist is selected.
- First refine / research / workbench are latched: a step completes on entry if its fact already happened. Belt delivery is polled from port buffers. A player alarm is told apart from the wave's own via `sim.in_step`.
- Scripted raid `tutorial_audit`: 2 crawlers, 1800 ticks, always counts as repelled at timeout, pod and inmates take 0 damage; normal waves are held until the audit step.
- R5X: the tutorial pre-approves the tier-2 research audit (the real audit needs plates + parts, far beyond a first lesson); T0/T1 techs are free from the start, so "finish your first tech" needs a T2 tech.
- R5X: new-game dialog has a "Warden's Orientation" toggle; fresh profile = ON and the dialog opens on first launch (`MetaState.launched`); existing profiles keep tutorial OFF.
- R5X: the tutorial card sits in `Hud.tutorial_slot()` and is hidden while a side sheet leaves the slot under 420 px.
## CX combat integration (decided without owner, review)
- Role numbers come from `tools/combat_model.gd` (analytic DPS/TTK from the data), not by eye: Bulwark `dmg_taken_mult` 0.6 -> 0.45 (lasts 2.2x an unsquadded inmate), Lancer volley `dmg_mult` 2.0 -> 2.5 (TTK on a brute 40% of a rifle inmate). `tests/test_combat_model.gd` guards both targets.
- `dmg_taken_mult` (HealthSystem.apply_damage) and `threat_mult` (ThreatModel.colonist_value) were declared in roles.json but read nowhere; both now go through `SquadSystem.role_mult`, 1.0 outside squads (goldens unchanged).
- `test_player_intervention_keeps_colony_alive_longer` measures the intent over seeds 1..5 (telegraph wind-ups made single seeds chaotic) instead of a per-seed floor.
- Process: adopted "Birds With Guns" ship checks into CLAUDE.md (decided without owner, review).

## Logistics 2 (owner, 2026-10-18)
Do belt splitters and mergers like Satisfactory with three separate splitter kinds: basic (round-robin), smart (per-output filter), priority/overflow; plus mergers. Add electricity now (was "later").
- Logistics 2 design (decided without owner, review): splitters/mergers are 1x1 belt nodes with
  3 outputs (L/F/R); power via poles (union-find networks), brownout = clamp(supply/demand, 0.2, 1),
  consumers without a pole run at 0.5; essence burner 100 power / threat 15 / waste, solar 25 clean
  (no day-night yet); no batteries yet; chip upkeep +10 power. Owner request overrides earlier
  "no power / splitters later".
