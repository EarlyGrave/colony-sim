# F2 report: kill feed + Warden PA
- New: view/feed_ticker.gd (3 lines, 6 s, fade; advance(dt) only while non-empty, no tweens/polling), view/pa_banner.gd (2.5 s, queue max 2, IGNORE input), view/feed_director.gd (bus -> lines), tests/test_feed.gd, tools/f2_shot.gd/.tscn.
- Surfaces (1 signal = 1 line): feed = enemy_killed, colonist_downed, building_destroyed; PA = wave_started, wave_incoming, crisis_started, research_completed, colonist_died, map_switched, outpost_lost, every 5th day.
- Death cause: ThreatSystem.damage_enemy(e, amount, cause="generic") + last_kill_kind()/last_kill_cause() (kept in the Hot holder, golden state dump unchanged; valid only inside enemy_killed). Turret -> "turret", colonist fire -> "melee". Colonist cause derived view-side from injuries (burn/starvation/bleed_out/generic).
- `outpost_lost(id)` added to event_bus (region F2), emitted in Expedition._charge_losses when a whole outpost crew is lost.
- FlavorPicker loaded via ResourceLoader.exists + has_method guards; keys feed.<enemy>.<cause> -> feed.<enemy>.generic -> feed.generic, pa.*; local FALLBACK bank in feed_director.gd when absent. Keys F1 should provide: pa.wave_started, pa.wave_incoming, pa.crisis, pa.research_completed, pa.colonist_died, pa.map_switched, pa.outpost_lost, pa.day, feed.downed, feed.building.
- Layout (hud.gd region F2, hooked at end of _o4_layout): feed bottom-right above thumb cluster, banner centred between portrait column and feed column 80 px below the strip (clear of tutorial slot). Hidden when empty, so phone-layout test unaffected.
- Tests: test_feed 5/5 (cap 3, expiry, queue, rect checks at 844x390 / 2532x1170 / 1280x720); test_phone_layout green; sharded full run 606 passed 0 failed.
- Cost: zero work per frame when idle; a few modulate writes while lines live (far below 0.1 ms). view_bench not run (needs GPU).
- Screenshot: scratchpad/f2_feed_pa.png (844x390 at 2.55).
