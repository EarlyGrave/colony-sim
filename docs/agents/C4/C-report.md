# C4 report
- docs/combat_batch_plan.md does not exist at dc62af4; implemented from the task text.
- Added derived band() fit/wounded/down (HealthState + sim.health), bleed_out_seconds(), stabilise(c, medic); config in data/health.json "band".
- Auto-rescue already exists (RescueGiver, work_type doctoring, to nearest free bed/shelter); left unchanged, no behaviour change.
- Colonist card shows band + bleed-out timer only (# region C4 in view/panels/sections/colonist_section.gd); no body-part table.
- Test: tests/test_health.gd test_band_and_stabilise. Goldens unchanged. Contract: sim_contract.md section 12.
