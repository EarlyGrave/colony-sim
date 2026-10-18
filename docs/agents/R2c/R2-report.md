# R2c report: research bench + job
Branch: worktree-agent-af2f3ebf36f77dad1 (based on 0fd972c). Not pushed.
Added: sim/research/operator.gd (ResearchOperator), sim/jobs/research_job.gd, sim/jobs/givers/research_giver.gd,
tests/test_research_bench.gd (7 tests), research_bench in data/buildings.json (2x1, 25 essence_ore, operator_slot "colonist", research_bench:true),
work type "researching" (skill crafting, giver "research") in data/work.json, "research": 45 in data/jobs.json,
balance research.bench_rate = 1.0, model key "research_bench" appended to data/models.json (own key only).
Shared-file touches (all region R2c): giver_registry.gd (1 line), view/building_3d.gd HEIGHTS entry (needed by test_every_building_has_3d).
Rate per tick = bench_rate * (0.5 + crafting_level/10); jobs gain crafting xp; chip hook = ResearchOperator.speed(sim, bench, operator).
Two benches work additively (each colonist adds its own rate).
## Calls into R2a (exact)
- `sim.research` (property, read via `sim.get("research")`)
- `sim.research.active() -> String`  (tech id or "" when none)
- `sim.research.add_progress(ticks: float)`
No stub in shared code: ResearchOperator.system() falls back to `sim.get_meta("research_stub")`, which tests use (StubResearch in test file).
Once R2a lands, tests can switch to the real system; the fallback can stay.
## Notes
- New work type "researching" appears in the work tab (default priority 3 for all colonists); state hash/goldens may shift if priorities are hashed.
- Bot hand-phase: no active tech without research core -> giver returns null, behaviour unchanged. Belt-by-day<=6 numbers must be re-measured after R2a merges (not measurable here).
- Accept checks: skill 0:10 ratio 0.5:1.5 (test), no bench 0 progress/1000 ticks (test), 600-tick tech = ceil(600/rate) working ticks +-2 (test; sleep breaks excluded), alarm flees, priority 0 disables.
