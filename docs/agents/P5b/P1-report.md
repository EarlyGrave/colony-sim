# P5b report: colonists spike at 250x250
Cause: MineGiver.find scanned all width*height bytes of mine_designated per idle-colonist assign() (62.5k cells at 250).
Fix: MapGrid keeps a designated-cell set + cached ascending-sorted index list (`mine_indices()`), invalidated in
set_mine_designated / set_tile (designation cleared). MineGiver iterates that list: same ascending order, same
strict `d >= best_d` tie-break => identical job assignment.
Before (bench --size=250 --enemies=0 --ticks=600 --seed=1): colonists avg 2.153 ms, p95 10.954 ms
After: colonists avg 0.712 ms, p95 0.293 ms (target p95 <= 2 ms met).
Not done: haul/harvest/scrub givers iterate stacks/plants (O(entries), not O(map)); not a cost at this scale.
Files: sim/map/map_grid.gd, sim/jobs/givers/mine_giver.gd, tests/test_job_cache.gd.
Tests: new test_job_cache (cache == brute force after add/remove/set_tile); full suite 335 passed, 0 failed.
