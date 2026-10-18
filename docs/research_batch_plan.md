# Research batch R1+R2 "sim contract + research tree" — plan (from prompter) — STATUS: QUEUED (base = dev branch after A2e merges)
One wave, 5 parallel Sonnet workers. Plans only. Common rules, region markers, report, test cmd: see `docs/automation_batch_plan.md`
("Common rules"). Reports: `docs/agents/<agent>/research-report.md` (<= 30 lines). New `class_name` -> `godot --headless --path . --import`.
Owner answers binding (DECISIONS "Roadmap answers"): R1 inside this wave; research cost = essence for big steps + part sets as tier
unlocks (Satisfactory milestones) + bench time always; later AI chips replace colonists; creatures may damage belts/machines.
## Shared design (all workers read)
- Tiers: T0 hand phase (workbench, refinery, walls, turret, storage, research_bench) and T1 basic machines (miner, belt, smelter) are
  UNLOCKED AT START -> current content and all existing tests stay playable. New gating starts at T2 (assembler, advanced recipes) and T3.
  `peaceful_defs()`/`make_sim()` default = all techs unlocked (opt `research_locked: true` enables gating in tests that need it).
- Tech state lives in `sim/research/research_system.gd` (`done: Array[String]` sorted, `queue: Array[String]`, `progress: Dictionary id->float`
  accessed via sorted keys), included in `SaveGame.state_hash`. Player commands (recorded via `_record`): `set_research(tech_id)`,
  `queue_research(tech_id, on: bool)`, `deliver_audit(tier: int)`.
- Operator abstraction: `ResearchOperator` contract = `{kind: "colonist"|"chip", speed(): float}`; only colonist implemented.
## R1a sim contract — owns `docs/sim_contract.md` (new), `tests/test_contract_doc.gd`, `tools/` none
Doc sections: tick order (copy of `Simulation.step()` incl. research slot: after `colonists`, before `logistics`), RNG rules (`sim.rng` call order,
no randi/randf/Time), command table (name, arg types, return, recorded?), determinism rules (no Dictionary-order iteration in tick paths, no
Callable/Vector2i-keys in state), bus signals list, JSON schema list per `data/*.json`, `state_hash` definition (canonical JSON, not `hash()`).
Accept: test parses doc table and asserts every public command method in `simulation.gd` (those calling `_record`) is listed, and every `data/*.json`
file name appears in the doc; >= 40 commands/files covered; doc <= 250 lines.
## R1b golden replays — owns `tests/golden/*.json`, `tools/make_golden.gd`, `tests/test_golden.gd`
5 scenarios (hand phase, belts+smelter, wave defence, crisis, 25-day bot-style command script), each 3000 ticks, format
`{seed, opts, commands:[[tick,name,args]], hashes:{"100":..,..,"3000":..}}` = 30 hashes. `test_golden` replays via `SaveGame` replay path and fails
with message `golden <name>: first divergence at tick N (expected X got Y)`. `godot --headless --path . -s tools/make_golden.gd -- --regen`
rewrites goldens (refuses without `--regen`; prints diff of changed ticks). Accept: 5 files, 30 hashes each, test < 60 s total; a deliberate
`balance.json` tweak makes exactly the test fail with first-divergence text; document regen in `docs/sim_contract.md` footer via a one-line hook
(region R1b). NOTE: goldens must be regenerated LAST by the orchestrator after all merges (research changes hashes); worker commits goldens from its branch.
## R2a research core — owns `data/research.json`, `sim/research/*` (research_system.gd, tech.gd), `sim/core/simulation.gd` (region R2a), `sim/core/save_game.gd` (region R2a), `tests/test_research.gd`
`research.json`: id -> {name, tier 0..3, prereqs[], cost {bench_ticks:int, essence:int (0 for small), }, unlocks {buildings[], recipes[], rules[]}, waste_mult}.
~14 techs: T0 4 (free/start), T1 4 (start-unlocked list), T2 3 (assembler, adv recipes, filters), T3 3 (higher throughput, higher waste/batch).
Essence cost >0 only for T2+ big steps (spent from the ledger on start, refunded on cancel before progress). Commands as above. Gating:
`BuildingSystem.placement_error` returns `"locked: <tech>"`, recipe availability filter in `BillSystem` (region R2a one-liner each), machines of locked
buildings cannot be placed; already placed stay working. Accept: locked building placement error for T2 assembler at start; after research it
passes; research completes after exactly `bench_ticks` of operator work (+-0); queue order deterministic; save->load mid-research equal `state_hash`;
replay of command log equal; cancel refunds essence exactly; every `unlocks` id exists in Defs (validation test); circular prereq rejected at load.
## R2b Audit Deliveries — owns `data/milestones.json`, `sim/research/milestone_system.gd`, `sim/buildings` hq-terminal hook (region R2b in `building_system.gd`), `tests/test_milestones.gd`
`milestones.json`: tier -> {parts {item: count}, letter {title, text}}; e.g. T2 = 40 plate + 10 gears (items from `data/recipes.json`/`items.json`; worker
verifies ids exist). `deliver_audit(tier)` consumes parts from HQ/terminal storage (delivery via existing deliver/haul to a `warden_terminal` building,
2x1, buildable only once, T0) and sets tier unlocked; partial deliveries accumulate (`delivered: Dictionary` sorted). Tier N+1 techs need tier N audit done.
Accept: consuming exactly the listed counts (no more); partial stock -> no unlock, counts persisted through save; unlock fires bus letter
(`letter_received`, reuse mail path) titled from json, once per tier; deterministic; delivered parts are lost to inventory (competes with building).
## R2c research bench + job — owns `data/jobs.json` entry, `data/buildings.json` entry `research_bench`, `sim/jobs/research_job.gd`, `sim/jobs/givers/research_giver.gd`, `sim/research/operator.gd`, `tests/test_research_bench.gd`
`research_bench` 2x1, cost essence_ore 25, T0 unlocked, skill = `crafting` (use existing skill ids, no new skill). Progress per tick =
`base_rate * (0.5 + skill/10)` from balance key `research.bench_rate`; colonist works only while at the bench and a tech is active; no bench -> 0 progress;
2 benches work on the one active tech additively. Chip hook: `ResearchOperator.speed()` interface + building field `operator_slot: "colonist"` in json.
Accept: skill 0 vs skill 10 speed ratio exactly 0.5 : 1.5 (+-1%); no bench -> 0 progress in 1000 ticks; with bench+colonist a 600-tick tech finishes in
ceil(600/rate) +-2 ticks; job respects work priority/ drafted/ alarm flee; bot hand-phase run still reaches belts by day <= 6 on seeds 1..3 (report numbers).
## R2d research UI — owns `view/panels/research_panel.gd`, `view/hud.gd` (region R2d), `view/game.gd` (region R2d), `tests/test_research_panel.gd`
Touch-first tech tree: horizontal scroll, one column per tier (T0..T3), node cards >= 64 px high (min 160x64), states locked (grey, shows lock reason:
missing prereq / tier audit) / available (accent) / done (check) / active (progress bar); card shows name, cost (bench time in days.hours, essence),
"adds X waste" when waste_mult > 1; tap = queue/unqueue (calls `sim.queue_research`); audit strip per tier with part counts and a Deliver button
(`deliver_audit`). HUD button >= 64 px opens panel; English text; ignore `DEVICE_ID_EMULATION`. Accept: all 14 nodes rendered, every Button/card
min height >= 64 px (test walks tree); tap queues tech (sim state changes); no panel code in `sim/`; screenshot check under
`xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- --out=<scratchpad>/research.png` on phone aspect 1080x2160 and desktop,
attach path in report; view only reads sim + calls commands.
## Merge order / risks
R2a first (others depend on its API: agree names above, stub if absent), then R2c, R2b, R2d, R1a, R1b last (goldens after everything).
Risks: gating breaking old tests (default unlocked), state_hash drift (goldens regenerated last), hq-terminal overlaps with deliver_job (reuse, do not fork),
Dictionary order in progress/delivered (use sorted keys). Deferred: AI chip operator, tainted-insight research, power.
