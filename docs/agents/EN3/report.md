# EN3 report (W3: Escape + Fight endings)
- New `sim/endings/fight_escape.gd` (`sim.fight_escape`, tick hook + save_game hash part, both in `# region EN3`); data in `data/endings.json` (`fight`, `escape`), building `uplink_array` (60 parts, 20 fuel cells, 30 power, unique).
- Fight: `sim.start_assault()` (Fight path + powered Uplink) sets ponr_fight, 3 scripted `start_wave(mult)` raids over 2 d; all dead -> `ending_won("fight")`; Uplink destroyed -> assault fails (retry).
- Escape: `contact_bandits()` (>= 3 covert sales, ponr_escape, fixed SE extraction cell) -> `pay_bandit_fee()` (60 from escape_credit) -> `start_extraction()` (pursuit wave + 1 d countdown); a living colonist within radius 4 at 0 -> `ending_won("escape")`, else retry.
- Suspicion/seizure raid already existed (N2 contraband), reused. Commands recorded (replay saves); documented in docs/sim_contract.md (condensed prose to stay <=250 lines).
- Tests: tests/test_fight_ending.gd (6, incl. end-to-end both endings, determinism). Quick suite green (goldens identical). Not done: view/HUD, metro_track raids, balance of mults (tests zero them), legacy-per-colonist payout.
