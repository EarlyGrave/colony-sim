# Roadmap after automation (A1/A2) — plan from prompter/designer
Five batches in priority order, 4 parallel Sonnet workers each. Plans only. Common rules, region markers, report format and test command:
same as `docs/automation_batch_plan.md` ("Common rules"). Engine move is expected later, so every batch keeps `sim/` pure and data-driven.
Pillars: (1) mining safe / refining dangerous; (2) automation multiplies throughput AND pollution; (3) prison planet, essence debt, creatures react.

## Batch R1 "Contract of the sim" (portability + save robustness) — do FIRST, cheap, protects everything after
Goal: freeze what a future engine port must reproduce. Why: the move to a serious engine is certain; golden data is the only way to prove a port is faithful.
- R1a contracts doc: owns `docs/sim_contract.md`. Documents tick order, RNG use (`sim.rng` call order), command list with arg types, bus signals,
  every JSON schema, state_hash definition, forbidden Godot-isms (Dictionary order, Vector2i as key, Callable in state). Accept: each command in
  `Simulation` appears in the doc (test greps `func ` names vs doc table).
- R1b golden replays: owns `tests/golden/*.json`, `tools/make_golden.gd`, `tests/test_golden.gd`. Format: seed + start opts + command log + state_hash every
  100 ticks for 5 scenarios (hand phase, belts+smelter, wave defence, crisis, 20-day bot run). Accept: replay matches stored hashes; deliberate balance change
  fails with a readable "first diverging tick"; regenerate command documented. A port must pass these byte-for-byte (hash over canonical JSON, not Godot hash()).
- R1c save robustness: owns `sim/core/save_game.gd` (region R1c), `tests/test_save_fuzz.gd`. Accept: save at random tick (20 seeds) -> load -> continue 500 ticks
  == uninterrupted run; versioned header + defs hash; corrupted/old file gives clear error, never a crash; autosave command-log compaction test.
- R1d determinism audit: owns `tools/audit_sim.gd`, `tests/test_sim_purity.gd`. Accept: static scan of `sim/` finds no Node/randi/randf/Time/OS/autoload use;
  unordered-iteration lint (`for k in dict` in tick paths must go through sorted keys); 3 runs with different Godot hash seeds equal.

## Batch R2 "Research: hand phase unlocks automation" (tech tree)
Goal: automation is earned, not given. Why: ties pillar 1 to 2 — first dirty hand-refining pays for research; each tier raises waste ceiling.
- R2a data+core: owns `data/tech.json`, `sim/research/research_system.gd`, `tests/test_research.gd`. Tech = {cost items/essence, prereqs, unlocks[building|recipe|rule],
  waste_mult}. Command `start_research`/`cancel_research` (recorded). Accept: locked buildings cannot be placed; research completes after exact cost; deterministic.
- R2b gating hooks: owns `sim/buildings/*` and `sim/core/simulation.gd` (region R2b), `tests/test_tech_gating.gd`. Accept: ~12 techs in 3 tiers (hand tools, belts+miner,
  smelter/assembler); old tests keep green via `peaceful_defs()` unlocking all; tier-3 machine has higher throughput and higher waste per batch.
- R2c work: owns `sim/jobs/givers/research_giver.gd`, research bench in buildings.json. Accept: colonist with skill researches at bench, speed scales with skill, bench is a
  hand-phase building; no bench -> no progress.
- R2d UI: owns `view/panels/research_panel.gd`, `view/hud.gd` (region R2d). Accept: tree as scrollable list (touch, >= 64 px), shows lock reason, cost, "adds X waste".
- Shared balance/QA by R2a: bot reaches belts by day <= 6 on 5 seeds.

## Batch R3 "Consequences scale with industry" (contamination + ecology)
Goal: industry visibly changes the planet and wildlife. Why: the core dilemma; creatures must react to the SMOKE, not to wealth.
- R3a contamination tiers: owns `sim/contamination/*` (region R3a), `data/balance.json` key `consequences`, `tests/test_consequences.gd`. Accept: per-region pollution
  (existing mutation field) drives ground effects: crop yield, node speed penalty (never depletion), colonist mood; 3 smelters >= 2.5x one.
- R3b ecology: owns `sim/ecology/ecology_system.gd`, `data/ecology.json`, `tests/test_ecology.gd`. Nests/herds per region; pollution makes some species flee/die, others
  (mutants) multiply; wave composition and direction depend on local pollution near machines/belts. Accept: same seed same ecology; clean map has only weak fauna; heavy
  pollution yields mutants within N days; waves target polluted belts first.
- R3c defence of lines: owns `sim/threats/*` (region R3c), `tests/test_belt_raids.gd`. Accept: creatures chew belts/machines (damage -> stall, repair job), turrets cover
  lines; no deadlock; perf bench stays under budget.
- R3d forecast/HUD: owns `sim/contamination/forecast_model.gd`, `view/hud.gd` (region R3d). Accept: forecast includes ecology pressure; 3-indicator HUD (pollution, pressure, throughput).
- Bot 25 days x 5 seeds: automation-heavy run ends no better than 1.3x baseline survival (no dominant strategy).

## Batch R4 "Expeditions and advanced biomes"
Goal: leave the start map for rare resources. Why: mining stays safe-ish but remote; refining advanced ore at home is the temptation.
- R4a biomes: owns `data/biomes.json`, `data/resources.json`, `sim/map/map_generator.gd` (region R4a), `tests/test_biomes.gd`. 3 new biomes (ash, crystal, swamp) with advanced
  ores (tier 2), hazards, fixed per-seed generation. Accept: each biome generates for seeds 1..5 with its resources; same seed equal arrays.
- R4b expedition core: owns `sim/expedition/expedition_system.gd`, `tests/test_expedition.gd`. Second MapGrid owned by the expedition, abstract timed trip (squad, supplies,
  travel ticks, return with loot capped by carriers). Commands `send_expedition`/`recall`. Accept: loot only items from biome; squad away -> colony short-handed; deterministic.
- R4c remote outpost: owns `sim/expedition/outpost.gd`. Accept: miners on remote nodes fill a buffer collected by caravans; outposts attract own creatures (R3b), no refining allowed there.
- R4d UI: owns `view/panels/expedition_panel.gd`, map picker. Accept: touch flow plan -> pick squad -> result letter; save/load mid-trip equal.

## Batch R5 "Onboarding and polish for strangers"
Goal: a new player understands the dilemma in 10 minutes. Why: projects without a tutorial die at first playtest; also freezes UX before an engine port.
- R5a scripted tutorial: owns `data/tutorial.json`, `sim/tutorial/tutorial_system.gd`, `tests/test_tutorial.gd`. Steps trigger on bus signals, skippable, saved. Accept: bot completes all steps on seed 1.
- R5b hints UI: owns `view/panels/tutorial_panel.gd`, highlights. Accept: one hint at a time, buttons >= 64 px, never blocks input.
- R5c scenarios: owns `data/scenarios.json`, start options. Accept: 3 presets (gentle/standard/harsh) with golden hashes (R1b format).
- R5d QA pass: owns `tests/qa_bot.gd` region, `docs/playtest_checklist.md`. Accept: 25 days x 5 seeds table in report; no new Known issues.

## Deferred (not scheduled): power/generators (owner: later; hooks `power` field in buildings.json), splitters/mergers (owner: later), audio (out of scope), stress/factions.
