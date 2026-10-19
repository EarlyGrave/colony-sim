# SR report: shelter ration (task 1 done), ore hauling (task 2 NOT done)
Task 1: needs_system._ration(): colonists who are hidden / in alarm / downed / sick and below ration.threshold (0.15) eat 1 stock item
(meal, then raw_food) every cooldown_ticks (40) at efficiency 0.6; ledger "eaten:*" + colonist_ate emitted. Numbers in data/needs.json "ration".
NeedsState.ration_next added (dumped into colonist_state golden hash -> goldens regenerated; real sim changes only where a raid hides colonists:
automation_chain from t2600, preset_short_stay from t2500). Tests: 2 new in tests/test_needs.gd (hidden-in-alarm ration, downed ration w/o helper).
Quick tests green (14/14).
factory_eval 1-10 / 60 d / jobs=3: alive>=8 9/10 (s3 hq_destroyed now, s9 fixed), audit 8, P1 5, P3 3, plates>=60 on 5/10 (s1,5,6,7,8), launch 0.
Meets alive/P1/P3; plates (need 6) and launch (stretch) not met. Chaotic: the fix shifts raid timelines (s3 lost instead of s9).
Task 2 (haul priority for full miner buffers, bot repairs remote iron miner): not attempted (time); no data change, so no kx_pillar_table run.
