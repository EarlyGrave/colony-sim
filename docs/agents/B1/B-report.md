# B1 report: pacing and presets (F1, F3)
Suite: 685 passed, 0 failed (sharded). Goldens regenerated once (all 8; hashes change from tick 100: research start set differs).

## Key finding
T0/T1 techs are FREE start techs (`free_tiers: 1` -> `done` at game start), so x3 on their bench_ticks alone changes nothing in play.
Fix: optional tech key `paid_start: true` (research_system.gd, `# region B1`) keeps a T1 tech out of the start set.
Only `conveyance` has it: belts now need real research (800 ticks + 6 essence, prereq hand_tools). drilling/smelting stay free
(gating them left the tutorial bot unable to place miners; their new essence costs 8/10 are dormant).
T0/T1 bench_ticks x3 per spec, except conveyance 800 (3600 pushed tutorial release past d16).

## Tutorial bot (tools/tutorial_report.gd DAYS=16; bot now researches conveyance before the belt chain)
seed | first refine | belt | hand phase | release
1 | 2.4 | 9.7 | 7.3 d | 13.5
2 | 1.4 | 8.5 | 7.1 d | 12.2
3 | 1.3 | 7.6 | 6.3 d | 11.4
(before: 4.3 / 2.8 / 2.5 d, release 11.1-11.2). test_qa_tutorial MAX_DAYS 12 -> 14.

## Presets (data/presets.json)
short_stay wave 0.6 / waste 0.45 (plan said 0.6: only -12 pts pol; 0.5 -13; 0.45 -15.8); standard unchanged; hard_time wave 1.15 / waste 1.15. No death_mult (not needed).
Preset bot table (tools/b1_preset_table.gd, bot_report baseline, seeds 1..5, 25 d):
preset | deaths | waves | pol% d20 avg | run ends
short_stay | 0 | 32 | 54.4 | 25 x5
standard_term | 0 | 32 | 70.2 | 25,25,24!,25,25
hard_time | 8 | 32 | 70.4 | 25,25,22!,22!,25
Deaths hard >= 1.5x standard OK (8 vs 0). pol d20 short <= standard-15 OK. "Waves repelled +1" only partly: wave counts equal (waves are pollution-paced);
short_stay survives 5/5 seeds to d25 vs 4/5 standard. Hard pol equals standard (saturates near 70%); difficulty shows in deaths/game over.

## Files
data/research.json, data/presets.json, sim/research/research_system.gd (region B1, 1 line), tests/golden/*, tests/test_presets_ramp.gd (new),
tests/qa_tutorial_bot.gd, tools/bot_report.gd (region B1: static preset_id), tools/b1_preset_table.gd (new; PRESETS=a,b env filter),
test fixes: test_presets (hard 1.15), test_research (belt locked at start), test_research_panel (zero-essence tech), test_qa_tutorial (14 d).
