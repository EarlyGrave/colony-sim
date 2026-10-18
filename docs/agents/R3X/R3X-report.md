# R3X integration report (branch r3x-integration, base 0cbc1b6)
- test_golden root cause: NOT hashing. tests/test_ecology.gd set `sim.threats.cfg["wave_duration_ticks"]=200` on the SHARED `Defs.get_default()` balance, so every later sim in the same process got wave_end_tick 2177 vs 2327 (only visible in the "threats" part, not in state_hash). Fixed the test (duplicate_defs). Golden alone passed, full suite failed.
- test_waves x2: T5 `starved_max` 4 clipped early waves so seed 2 survived to wave 4. `starved_max` 4 -> 6 (data/ecology.json); tests untouched, 11/11 green.
- threat_v2 ON (data/threat.json). Belts are targets (new Enemy.Target.BELT, one candidate per 8x8 region, value base.belt*min(sqrt(count),4), rebuilt every 60 ticks); creatures walk to it and T3 bites. Decoys use Decoy.threat_now; busy chip = state_mod.chip x2. Waves aim via pick_target (v2 _choose_target).
- Tests: 8 crawlers 15 cells from a lit beacon pick it over a belt 5 cells away (72+/80 over 10 seeds), belts targetable, belt bitten.
- AI chip balance (DECISIONS, decided without owner): unoperated smelter/assembler 0.6 (stateless floor trick, save-safe), chip 1.0 (waste x1.3, threat x2 kept). data/chips.json keys unoperated_speed / processor_chip_speed. test_chips and test_machines timings updated (lightning event erased in chip tests).
- HUD: 64 px "Ring bell" in building_section.gd (# region R3X, disabled while ringing/cooldown); nests drawn in view/effects_3d.gd (# region R3X): voxel 3-layer mound, pulses when bank >= default_unit_cost. Tests added.
- QA tooling: BeltGrid hp_lost_total / repairs_total counters (unhashed), chip profile now installs real chips (free item+tech) from day 3.
- Goldens regenerated (peaceful_mining/contamination_crisis/save_load unchanged hashes; raid_turrets from tick 2100, automation_chain from 600).
## QA r3 (25d x seeds 1-5; end day/cause, kills, lost bld, belt hp lost)
baseline:  23 planet_dead/25/15 hq_destroyed/24 hq_destroyed/25 = 112 d; belt hp lost 702/728/334/472/631
automation: 25/25/17 hq_destroyed/25/25 = 117 d (1.04x); belt hp lost 680/520/292/720/584
chip:       25/25/25/25/25 = 125 d (1.12x); belt hp lost 589/560/296/256/1232
Survival ratios <= 1.3x OK. Repairs = 0 for all bots (bot never stocks plates for RepairGiver; belts stay damaged). Seed 3 baseline/automation lose HQ at d15/d17 with v2 (before: planet death d22) - v2 raids are harsher; owner review.
## Open
- Full suite: 468 passed, 0 failed, twice in a row (215 s, 232 s).
