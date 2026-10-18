# KX report — K reconcile
Root cause: wave count was purely timer-driven (pollution only scaled strength), so throttling could not reduce waves (wave_interval_mult 4: 7/7/7 for baseline/throttle/mining).
- Pillar fix (threat_system.gd region K1): pollution-wave countdown is re-scaled every 30 ticks from the last wave end by
  `balance.pacing.pollution_interval` {lo .45, hi .7, clean_mult 10, dirty_mult .5} (x contamination fraction curve). Preset
  `wave_interval_mult` = 1.0 (<=1.5), audit interval 8/6/5 d (was 6/4/3).
- Tables (tools/b1_preset_table.gd --days=21, 5 seeds): short 4.8 / standard 6.6 / hard 7.2 mean waves (targets 4/6/8 +-1), 0 deaths.
- Pillar (tools/kx_pillar_table.gd, new; standard d21): baseline 6.6, throttle 4.2, mining 4.0 (gap 2.4). Hard: baseline 7.2, throttle 5.8.
  Sweep: old mult 4 -> 7.0/7.0/7.0; mult 1 -> 10.4/10.2/10.0; static curve before live rescale -> 4/4/4.
- k2_enabled and k5_enabled now true. preset id travels as opts `preset_id` (StartOpts.preset_opts); milestones.k2_preset_id() reads it.
- K1 audit calls `milestones.k2_consume_decoy()` and skips the home audit once (test_decoy_skips_home_audit).
- Added `outpost_step_text()`, `k2_demand_text()`; Reviews sheet shows demands + outpost step, has_method guards removed (hud/reviews_panel).
- Bugs found: (1) K3 chip button was freed with the top-flow row (never visible) -> reparented in _o4 build, relayout on appear;
  (2) campaign save dropped k2 outpost counters -> saved/restored (`k2` key, milestones.k2_export/import).
- Screenshot 2532x1170 (844x390 @DPR3) with chip "Next audit in 5d": docs/agents/KX/shot.png (tools/screenshot.gd gained --preset=).
- Threats bench (perf_threat --n=300 --size=250, 5 runs): avg 2.16-2.34 ms, stable but above the 2.0 contract; perf_budget.json NOT tightened (nothing to tighten).
- Goldens regenerated once on purpose (0/30 hashes changed; files rewritten). Tests adjusted: test_k2/test_k5 flag defaults, test_presets, test_campaign (k2 off for parity).
- Suite: sharded 718 passed, 0 failed, twice in a row. web_smoke.py PASS. No background runs left.
