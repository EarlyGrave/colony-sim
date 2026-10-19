# EN2 report (Submit ending)
- ShuttleSystem: `manifest`/`seats()`/`set_manifest`; on path "submit" `parts_need()` = seats x seat_parts (data/shuttle.json); no path = old 24-part list.
- `ThreatSystem.start_wave(strength_mult := 1.0)` (region EN2); siege uses `siege_mult()` = (1+pollution_frac) x (1+notice bonus).
- C4 launch-window notices every 8 d after the Submit PoNR (+0.1, cap +0.5), stop at launch/win; data-driven.
- Win on Submit: freed/stayed recorded, quest flag `ng_new_names` (NG+ hook), `ending_won("submit")`; no-path win unchanged.
- State: state_parts appends manifest/freed/stayed/notices only when non-default (goldens identical). Command `set_manifest` in sim_contract.md.
- Tests: tests/test_shuttle_manifest.gd (6) + test_s1_shuttle pass. Not done: UI for manifest, Legacy freed/stayed consumption, NG+ new-names generation.
