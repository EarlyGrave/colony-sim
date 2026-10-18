# K1 report — calm-after-hit + sentence-audit clock
Sim (threat_system.gd `# region K1`): preset opts `audit_days`, `calm_mult`, `wave_interval_mult` (start_opts.gd, data/presets.json);
balance.json `pacing` {floor_pts_per_day 0.7, calm_after_hit_days 2.0}. Active ONLY when opts carry them (presets); plain sims unchanged.
- Audit patrol: every audit_days (6/4/3) start_wave with 0.7*days*wave_mult points, even unawakened; does not reset the pollution timer.
- Pollution (timer) waves: interval x4 on all presets so audits dominate the count (otherwise ~6/6/6 + audits).
- Calm: wave that kills a colonist/breaks a building -> no regular wave for 2d x (2/1/0.4). Audits ignore calm.
- API: `sim.threats.next_audit_tick()`, `days_to_audit()` (-1 when pacing off).
Bot table (tools/b1_preset_table.gd --days=21, 5 seeds), before -> after:
| preset | mean waves d21 | deaths | ends |
| short | 6.4(old ~6.6@25d) -> 5.0 | 0 | all alive d21 |
| standard | -> 7.0 | 0 | all alive |
| hard | -> 8.6 | 0 | all alive |
Targets 4/6/8 +-1 met (short 5.0, std 7.0, hard 8.6 ~ upper edge). Hard clean-colony audit by d10: audits at d3/6/9 (test: audit fires unawakened).
Seed 3 d21 alive on all presets (not worse). Deaths short<std<hard NOT demonstrated: 0 deaths on all at 21d (bot too strong; was 0/1/0 at d25 before).
Goldens regenerated once: 0/30 hashes changed (files rewritten for state-dump var list). test_presets standard test updated.
Tests: tests/test_k1_pacing.gd (5). Full suite: 705+ green after the test_presets fix.
Note: wave_interval_mult 4 is a big change to pollution-wave cadence in presets; orchestrator may want to tune (balance lever).
