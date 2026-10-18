# BX report: B-batch reconcile
Flipped ON by default: balance b2_pollution.enabled, threat b2_clean_outpost.enabled, balance b3.enabled, balance b4_enabled. Goldens regenerated once (0/30 hashes changed on all 8). Sharded suite 701 passed, 0 failed (twice). web_smoke PASS.

## 1. B2 raid_mult (tools/b2_table.gd, seeds 1..5, 25 d, avg pol% d20; off -> on)
profile | raid_mult 0.8 | raid_mult 1.0 (KEPT)
baseline | 70.2 -> 74.8 (+4.6, out of +-3) | 70.2 -> 67.3 (-2.9, within +-3)
throttle | 57.9 -> 49.1 | 57.9 -> 44.1 (<=60 OK)
mining | 7.0 -> 0.0 | 7.0 -> 0.0
threat.json b2_clean_outpost.raid_mult is now 1.0 (miners are still ignored by creatures at pol <= 20%).

## 2. B3 wiring
Rules auto_throttle_above / evacuate_low_hq unhidden (shorts "Throttle", "Evac HQ"; popup buttons 96 -> 80 px wide so the 8-button Orders row still fits 844 px, test_phone_layout green).
ReviewsPanel registered in panel_registry (`# region B3`, "Reviews" button); no overlap with B5 wave card (own side sheet).
evacuate_low_hq was a no-op (HQ is already a shelter): redefined as "a shelter below 50% hp is not used on alarm; hidden colonists inside come out" (job_system.gd region B3). Test test_evacuate_low_hq_rule (off / healthy / hurt).

## 3. Layout
Hint toast (bottom-left) overlapped the Warden PA banner on a 390 px screen; the toast now yields while the banner would overlap it (hud.gd region F2 tail). Screenshots: docs/agents/BX/report_card.png (844x390 wave card + banner), orders.png.

## 4. Review bot (tools/review_bot.gd: tutorial bot, then free play, 25 d)
Original thresholds (debt 25% / tier 3 / waves 3): 0/5 seeds got 3 reviews (tier 3 needs 120 plates; bot reaches tier 1; debt 15-36%).
Retuned data/milestones.json: R1 debt_paid 8%, R2 waves_repelled 2, R3 debt_paid 14%.
seed | reviews at day | end
1 | 13.5, 13.9, 13.9 | alive d25
2 | 12.2, 12.6, 12.6 | alive d25
3 | 11.4, 11.9, 11.9 | alive d25
4 | 12.3, 12.9, 13.5 | alive d25
5 | 13.4, 21.2, 21.2 | alive d25
=> 5/5 (target >=4/5). Tier-based review dropped (not reachable without plate chain).

## Other fixes
ContractSystem.required_essence: clean_bonus no longer lifts a 0-essence demand to 1. Tests updated: b2 on-by-default, b3 on-by-default, presets waste test (b2 off in that sim), b4 contract demand loop 12 -> 80 tries (rng-order fragile).
Not done: qa_r3 seed-3 survival with rules on (rules are opt-in toggles, default off).
