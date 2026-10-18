# B3 report: Parole Reviews + throttle/evacuate rules
Gate: `balance.json` key `b3.enabled` (false). Goldens untouched; sharded suite 686 passed, 0 failed.
- `data/milestones.json`: `reviews` list (debt_paid_pct 25 -> 10 essence, tier 3 -> 20, waves_repelled 3 -> 30). Sequential, active after tutorial finished (or no tutorial).
- `sim/research/milestone_system.gd` (region B3): `current_review`, `review_progress`, `tick_reviews` (1/s, called from `Simulation.step` region B3), reward dropped at map center via ledger "review", letter + story_event. `state_parts` adds a row only once a review is done.
- Rules (hidden:true, default off, need b3 on): `auto_throttle_above` (hook in `BuildingSystem.refining_capped`, 40%), `evacuate_low_hq` (JobSystem: on alarm with no shelter, HQ below 50% hp becomes the shelter).
- `view/panels/reviews_panel.gd`: strip panel, NOT wired into HUD (HUD owned by B5); rules are hidden so the HUD does not list them yet. Orchestrator: unhide/wire when flipping.
- Tests `tests/test_b3_reviews.gd`: off by default, order, determinism (state hash), throttle rule.
NOT done: bot acceptance (tutorial-then-free bot 3 reviews on >=4/5 seeds; qa_r3 seed 3 survival with rules on) was not run; the evacuate rule is untuned.
