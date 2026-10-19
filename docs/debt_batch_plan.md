# Debt batch plan (D1-D4): make a real factory_bot reach audit tier 2 / P1-P3 / launch
Context: docs/agents/YX/Y-report.md. Real factory_bot (60 d) makes <=420 refined, ~270 waste, 0 parts, 0 audit2.
Bottlenecks: (a) debt 30-90 refined/colonist due in 12 d unpayable -> despair escapes; (b) waste pollution; (c) parts never made.
Rules for ALL workers: start `git reset --hard claude/colony-sim-godot-4jftsm`; shared files only inside `# region D<n>`; sim/ deterministic;
all tests green; commit often (container may restart); never push; never `pkill` broadly; leave NO background runs; temp files via `mktemp -d` only;
report <=30 lines in docs/agents/D<n>/debt-report.md. Use D4's harness (tools/factory_eval.sh) once it lands on your branch (else factory_bot_report.gd).

## Acceptance (10 seeds, 60 d, standard, real factory_bot)
audit tier 2 >=6/10; P1 >=5/10; P3 >=3/10; launch >=1/10; pillar holds (tools/kx_pillar_table.gd: throttle >=2 waves below baseline).
Workers report their own delta; the orchestrator measures the merged result.

## D1 debt pacing (data + minimal sim) — owns data/debt.json, data/balance.json (debt keys), sim/colonists debt code, tests/golden/*, tests/test_debt*.gd
- Build a small model (tools/debt_model.gd, D1-owned): income = refined/day of a decent factory (YX: 420 refined/60 d ~ 7/day, ramping from ~d8) vs debt schedule.
- Retune debt_min/max, due_days, interest/penalty, despair_per_day so a decent factory pays by ~d40-50 while an idle colony still hits despair (debt stays core pressure).
  Options: staged tranches (due d12/d28/d45), smaller first tranche, petition cuts kept. Minimal sim change only if data cannot express it.
- ONLY D1 regenerates goldens (`tools/make_golden.gd -- --regen`), once, at the end; list changed ticks in report.
- Tests: debt schedule asserts, model-vs-sim sanity, despair escape still fires for a zero-payment colony.

## D2 waste handling — owns data/buildings.json (new/changed waste sink only), data/research.json (unlock), sim/buildings waste-sink code, sim/contamination only if required, tests/test_waste_sink.gd
- Make a waste sink usable early (by ~d10): cheap Waste Dump / compactor / ash-beacon variant that consumes waste items (and/or cuts the 0.02 pollution/unit/day bleed), cost <=15 plate-equivalent ore, no research gate or an early one.
- Gate behind default-off flag in balance.json (`waste_sink_early: false`); orchestrator flips after measuring. Tests run with flag on and off.
- Pillar must hold: run tools/kx_pillar_table.gd with flag ON; the sink must not remove the refining-is-dangerous cost (cap it by throughput, e.g. 1 waste/ 100 ticks, power use).
- Acceptance alone: with flag ON a bot refining 400 refined stays under pollution cap 50% and planet_dead is gone on seeds 1-10.

## D3 factory_bot — owns tools/factory_bot.gd, tools/factory_bot_report.gd (tools only; no sim/data edits)
- Plate reserve: repairs/fuel cells may not drop plates below a reserve (e.g. 12) once an assembler is planned; parts take priority over fuel cells until 24 parts queued.
- Assembler chain (workbench -> assembler with copper/iron smelting feeding it) built by ~d25 (log build day in report).
- Waste disposal: build D2's sink when `waste_sink_early` exists (read flag; bot works with flag off too); otherwise set Taint cap rule 50% and burn waste in ash beacon.
- Debt payment priority: deliver refined to the debt item before turrets/fuel/petition, keep a floor for turret cost; pay tranche before due day.
- Test the bot via D4 harness on 10 seeds; report per-seed table before/after.

## D4 evaluation harness — owns tools/factory_eval.sh, tools/factory_eval_summary.gd (or .py), tests/test_factory_eval.gd (smoke only)
- `tools/factory_eval.sh [--seeds=1-10] [--days=60] [--preset=standard] [--jobs=N] [--ov=JSON]`: one headless godot process per seed, N parallel (default nproc), per-seed timeout, outputs to mktemp -d, cleans up on exit (trap) and only kills its own PIDs.
- Total wall time <5 min for 10 seeds x 60 d (measure; report jobs used). Deterministic output order.
- Summary table columns: seed, end reason, alive, audit tier, P1 P2 P3 P4, parts, launch, pollution %, debt paid %, refined, plates, waste. Last rows: totals vs the acceptance thresholds (PASS/FAIL).
- Reuse tools/factory_bot_report.gd output (extend only through a new per-seed JSON line printer owned by D4; coordinate with D3 via `# region D4` in factory_bot_report.gd).
- Document usage in the script header; commit as soon as it works (others depend on it) — first commit within the first third of the work.

## Merge order (orchestrator): D4 -> D3 -> D2 -> D1 (goldens last), full suite x2, web_smoke, pillar table, then run harness and flip D2 flag if acceptance improves.
