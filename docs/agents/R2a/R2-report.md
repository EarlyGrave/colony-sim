# R2a research core report
Files: `data/research.json` (14 techs: T0x4, T1x4, T2x3, T3x3), `sim/research/{tech,research_system}.gd`, `tests/test_research.gd` (11 tests),
region R2a hooks in `simulation.gd`, `save_game.gd` (state_hash), `defs.gd` (load/validate), `building_system.gd`, `bill_system.gd`,
`autoload/event_bus.gd` (signal `research_completed(tech_id)`), `data/balance.json` key `research` {free_tiers:1, essence_item}.
## Public API (`sim.research`, class ResearchSystem)
- Commands (recorded, on Simulation): `set_research(tech_id)->bool` (front of queue), `queue_research(tech_id, on)->bool`.
  Essence is spent when a tech is first queued/activated (`paid`), refunded exactly if unqueued with zero progress; locked/unaffordable -> false.
  `deliver_audit` is NOT here (R2b owns it).
- R2b: `research.unlock_tier(tier:int)` after a tier audit completes (tier T techs need `tier_unlocked(T)`; tiers <= free_tiers need none).
  Opts for tests/bots: `research_audit_tiers: [2]` pre-grants audits.
- R2c operator: `research.add_progress(work: float) -> String` (work = bench ticks at speed 1.0; returns completed tech id or "").
  Progress goes to `active()` (first queue entry with met prereqs/tier). Not a command: operators call it from deterministic jobs.
- R2d queries: `sim.defs.research`, `done`, `queue`, `active()`, `lock_reason(id)` ("", "done", "tier audit T2", "needs <id>"),
  `can_afford(id)`, `progress_of/fraction/bench_ticks(id)`, `waste_multiplier()`, `building_tech(def_id)`, `tier_unlocked(t)`.
- Gating checks: `building_unlocked/recipe_unlocked/rule_unlocked(id)`. `placement_error` -> `"locked: <tech_id>"`; `add_bill` refuses locked recipes;
  `set_rule(on)` refuses locked rules.
## Gating switch
`research.gating` is false by default (everything unlocked, all tests unchanged). Enable with start opt `research_locked: true`
(`Simulation.new(seed,bus,defs,{research_locked:true})`) or `sim.research.gating = true` in a test. The real game must pass the opt (R2d/orchestrator).
Techs of tier <= free_tiers are done at start; buildings/recipes/rules not listed in any tech are never gated (research_bench is ungated).
## Notes
- `waste_multiplier()` is exposed but NOT yet applied to contamination (balance decision for orchestrator).
- state_hash now includes research state -> goldens (R1b) must be regenerated last. SaveGame.VERSION unchanged (replay format same).
- Validation: `Tech.validate(research, defs)` (unknown ids, tiers, cycles) runs in `Defs.validate()` and push_errors at load.
- Operator progress is not a command: a save/load replay reproduces research only if operators (jobs) are deterministic sim ticks, which they are.
