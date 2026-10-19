# D2 report: early waste sink (flag off by default)
- New building `waste_compactor` (data/buildings.json): 1x1, cost 10 essence_ore, no research gate, `waste_sink` {item waste, every_ticks 100, per 1, pollution_per_unit 0.01}.
- Flag `waste_sink_early` (balance.json, default false). Off: placement returns "locked: waste_sink_early" and nothing ticks; goldens untouched (not regenerated).
- Code: `# region D2` in sim/buildings/building_system.gd; 3D scale entry in view/building_3d.gd.
- Throughput cap: 6 waste/day per compactor, 0.01 pollution per unit. A batch makes 4 waste; 400 refined = ~270 waste, so one compactor needs ~45 days: refining stays dangerous.
- Tests: tests/test_waste_sink.gd (3). Sharded suite: 779 passed, 1 failed (test_building_3d missing entry), fixed afterwards, that test now green; full suite not rerun after the fix.
- Pillar (kx d21 standard_term, 5 seeds, flag ON): baseline 7.0, throttle 4.2, mining 4.0, gap 2.8 (>=2). Bots do not build the compactor, so unchanged by construction.
- NOT measured: acceptance "bot refining 400 stays under 50% pollution, seeds 1-10": factory_bot doesn't build the compactor yet (D3). After D3 run tools/factory_eval.sh with --ov='{"balance":{"waste_sink_early":true}}'.
