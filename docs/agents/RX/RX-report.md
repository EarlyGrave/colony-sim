# RX reconcile report
Branch: rx-reconcile (base 65047d9). Full suite: 415 passed, 0 failed. Not pushed.
- Bench/tests: ResearchOperator uses real `sim.research` (stub fallback removed); test_research_bench uses a Probe over the real core (hand_tools re-opened + queued).
- Fixed duplicate `"research"` key in data/balance.json (R2c bench_rate was shadowed by R2a's block); merged into one block.
- Gating: GameController.new_game sets opts["research_locked"]=true. Test: fresh locked game has research_bench, workbench, refinery, miner, belt, smelter, storage ports, wall, turret; assembler stays locked.
- Research panel: SAMPLE_* and local fallbacks deleted; adapter reads active/done/queue/lock_reason/can_afford/fraction/bench_ticks/tier_unlocked. Tiers stack vertically with wrapping cards (HFlowContainer, 146x72 min, all 4 tiers reachable in the panel's vertical scroll). Audit strip shows "not required"/"pending" from tier_unlocked; part lists + Deliver need R2b (data/milestones.json, sim.deliver_audit) - used if present.
- tools/screenshot.gd: --panel=research now sets demo state (T2 audited, assembly 45%, filters queued). Screenshot: scratchpad/rx_research.png (locked, available, active w/ progress, done all visible).
- Waste: `BuildingSystem._research_waste` applies `research.waste_multiplier()` to contaminating outputs of every recipe (hand refinery and smelter share work()). Fractional part rolled on sim.rng only when mult != 1. Tests: refinery 4 -> 5 at x1.25; smelter ~1.5x over many batches.
- Save bug: StartOpts drops `opts.crate` in sorted-key order always (identical before/after JSON round-trip). Test test_multi_item_crate_order_survives_save.
- Goldens regenerated last (tests/golden/*.json), committed.
- Open: audit parts UI waits on R2b; "(short)" essence tag also shows on locked cards (cosmetic).
