# Design review, session 4 (game designer, bots only)

Sources: PROGRESS/DECISIONS/roadmap, `tools/qa_r3.gd` (partial), `tools/tutorial_report.gd`, `tools/combat_model.gd`, and a scratch copy of
`bot_report.gd` with preset opts (25 days x seeds 1..5 x 3 presets). No real-player or phone playtest was possible (headless).

## 1. The loop as a player lives it (standard_term)
- 0:00-0:20 (day 0-1): a crate, a few inmates, mine ore by hand (safe), haul to storage. Tutorial walks mining -> dirty refining.
- ~day 2: first hand refine; contamination bar jumps. Dilemma is shown immediately and well (tutorial "dirty" 1.6-2.4 d).
- day 3-5: research bench; T0/T1 techs (belts, miner, smelter) cost 600-1500 bench ticks each, essentially free in essence. Belt by day 4-7.
- day 5-8: first scripted raid; turrets; "Audit Deliveries" at the terminal (plate 40 + parts 10) opens T2 at ~day 8 (tutorial bot).
- day 8-12: decoy beacons, forecast, tutorial release at ~day 11. Then free play: contracts, debt quotas, crises, waves every ~3.5 days.
- day 15-25: pollution is 70-85%, waves grow with nests; players either keep refining (death spiral) or throttle (refine_cap, T2).
- Expeditions (T2 tech, 25 essence) exist but nothing in the loop asks for them.

## 2. Bot numbers (25 d, seeds 1..5; refine/belt/machine/research = day of first event)
| preset | first refine | first belt | first machine | first research | audit T2/T3 | waves faced / repelled (avg) | deaths | pol% d10 / d20 (avg) | ends |
|---|---|---|---|---|---|---|---|---|---|
| short_stay | 0.2 | 1.07 | 1.4-5.3 | none (bot never researches) | no / no | 6.6 / 3.4 | 4 (seed 3) | 31 / 66 | 4 alive, 1 hq_destroyed d24 |
| standard_term | 0.2 | 1.07 | 2.9-5.0 | none | no / no | 6.4 / 3.8 | 0 | 31 / 77 | 4 alive, 1 planet_dead d24 |
| hard_time | 0.2 | 1.07 | 2.9-5.0 | none | no / no | 6.2 / 3.0 | 11 (s3,s4) | 32 / 75 | 2 alive, hq_destroyed d21, colonists_dead d21, +1 alive |
- Tutorial (player-like) bot, d: dirty refine 1.6-2.4, research 3.4-4.9, belt 4.4-7.5, audit 7.7-8.4, release 10.9-11.6; T3 never reached; 0 deaths.
- QA r3 baseline (partial, 4 seeds): 3 alive d25, 1 planet_dead d24; kills 14-30; belt_hp_lost 224-680, repairs 0 (all seeds).
- Combat model: Bulwark lasts 2.22x an inmate; Lancer kills a brute in 8.4 s vs 21 s rifle inmate. Unsquadded inmate dies to a crawler/brute in ~17 s.
- Expeditions: possible only after T2 research; bots never send one (0 sent).

## 3. Problems, ranked
1. **Pollution runs away regardless of preset.** d20 contamination 54-87% on all presets; short_stay (waste x0.8) ends at 66% vs 77%. The
   "throttle" choice is not rewarded enough, so the dilemma resolves to "refine and lose slowly". Evidence: table; planet_dead d24 on standard seed 3.
2. **Presets barely differ in difficulty feel.** short_stay vs standard: pol d20 -11 pts, waves repelled 3.4 vs 3.8 (short_stay is no easier);
   hard_time kills colonists (11 deaths) while standard has 0. Difficulty is a cliff between standard and hard, not a ramp.
3. **Automation arrives too early and is free.** Hand-phase research costs 0 essence and 600-1500 bench ticks (~0.5-1 day); belt+miner+smelter by day 4-7,
   machine day 1-5 for the bot. Hand refining is never a phase the player lingers in; pillar 2 ("automation earned") is weak.
4. **Mining is not "safe" enough to matter; refining danger arrives as a slow gauge, not events.** Waves scale on nests/pollution, but nothing
   punishes mining expansion or rewards it as the clean path. Mining income is capped by hauling, not by risk, so there is no mining-only strategy.
5. **Research is a one-click tax, not a decision.** T0/T1 cost no essence, T2/T3 do (10-60); tech waste multipliers (1.25-1.5) are only on T3 techs
   that nobody reaches by day 25. Research queue is linear; no mutually exclusive choices.
6. **Audit gate has no pressure and is slow for the bot.** Plate 40 + parts 10 needs smelter+assembler (T2) first - circular - and bots never reach T2/T3
   (0/15 runs). Tutorial bot gets T2 at d8, so a player could, but nothing pulls them to T3 (plate 120, parts 40, copper 30).
7. **Belt repair is a dead system.** repairs = 0 on every seed while belt_hp_lost 224-680; plates are never stocked because plates need T2.
   Belts therefore only degrade. Known issue in PROGRESS ("bots never stock plates").
8. **Expeditions are a dead end for the loop.** T2 tech + sling, collateral 100, nothing in contracts/debt requires cinder/prism/bog ores.
   No Recall button in UI (Known). Advanced biomes give no reason to leave home.
9. **Combat help is under-delivering.** Squads cut deaths per wave -53% but per repelled wave only -11% (target 30% missed). Waves repelled
   3-4 of 6-7 faced: more than 40% of waves are not repelled, yet the colony mostly survives -> losses are structures (4-10 lost per run) not people, which feels unreadable.
10. **Hard_time spirals via HQ and colonist death**: seed 3 hq_destroyed d21, seed 4 colonists_dead d21 (all 7 died). Single points of failure with no
    comeback tool (no retreat/evacuate rule, no "pause refining" auto-rule).
11. **Pacing gap day 12-25.** After tutorial release (d11) the player has no guided goal; the end condition is pure survival or debt. Contracts/crises
    exist but bots show 0-few debts paid; no mid-game milestone beyond audit T3.
12. **Chip automation is a weaker lever than expected**: chip-heavy survival is within 1.3x of baseline by design (QA 112/117/125 days) -> no
    dominant strategy, but also little reason to build chips. Unchipped processors at 0.6 speed (flagged "review") punish early machines.
13. **Phone UX load.** Many strips/panels (automation strip floats with a gap, research tree panel, expedition dialogs, squad bar, radial). Hint
    density is the only onboarding after d11 (standard shows only new hints). No phone playtest exists.
14. **Info clarity of consequences.** Forecast can improve after the refinery dies (Known), colonists ignore enemies with alarm off, enemies overlap
    - players cannot tell why a wave beat them.

## 4. Fixes
| # | fix | size | data / files |
|---|---|---|---|
| F1 | Make hand phase last: raise T0/T1 bench_ticks x3 and add small essence costs on drilling/conveyance/smelting | S | `data/research.json` |
| F2 | Pollution feedback: faster natural decay below a threshold when refiners idle; stronger reward for "refine_cap" (raise crop/mood bonus at low pol) | M | `data/balance.json` `consequences`, `sim/contamination/` |
| F3 | Re-tune presets as a ramp: short_stay waste 0.6 / wave 0.6, hard_time wave 1.15 / waste 1.15, add `death_mult` for HQ hp | S | `data/presets.json`, goldens regen |
| F4 | Mining-safe pillar: mining zones/miners get "clean ore" bonus (e.g. +15% essence_ore value to contracts) and exposure-free (creatures ignore mining outposts below pollution X) | M | `data/threat.json`, `data/contracts.json` |
| F5 | Repair loop: let HQ/bench produce `plate` from scrap hand-phase (recipe) so belt repairs happen without T2; bot stocks plates | S | `data/recipes.json`, `tools/bot_report.gd` |
| F6 | Give expeditions a purpose: contracts/crises demand cinder/prism/bog items; Recall button in the map switcher | M | `data/contracts.json`, `data/crises.json`, `view/` expedition dialog |
| F7 | Mid-game goal chain after tutorial: 3 "Parole Reviews" (debt paid %, audit T3, repel N waves) with essence/perk rewards | M | `data/milestones.json`, `sim/research/milestone_system.gd`, HUD |
| F8 | Auto-throttle rule: "stop refining above contamination X" plus "evacuate to HQ" on low HQ hp | M | `data/rules.json`, `sim/core/simulation.gd` rule hooks |
| F9 | Research choices: pairs of exclusive T2/T3 branches (clean filters vs bulk throughput) so waste multipliers are a decision | M | `data/research.json`, `sim/research/` |
| F10 | Wave readability: post-wave report (lost buildings, who attacked what, why) and wave_incoming ETA marker on phone | M | `view/hud`, `data/flavor` text, `bus` signals |
| F11 | Squad tuning pass to hit the 30% target (Bulwark taunt radius/cost, medic bleed time) | S | `data/weapons.json`, `data/roles.json`, `tools/combat_model.gd` |
| F12 | Phone pass: merge automation strip into radial menu, fix strip gap, one real-device measurement | L | `view/*`, `tests/test_phone_layout` |

## 5. Proposed next batch (5 workers, disjoint files)
- **B1 pacing and presets** (F1, F3): `data/research.json`, `data/presets.json`, `tests/golden/*` regen. Accept: hand phase >= 3 days in tutorial bot; presets differ by >=1.5x in deaths.
- **B2 pollution and clean-mining pillar** (F2, F4): `data/balance.json`, `data/threat.json`, `sim/contamination/*`. Accept: pol d20 <= 60% on standard with throttling bot; mining-only bot survives 25 d.
- **B3 mid-game goals and rules** (F7, F8): `data/milestones.json`, `data/rules.json`, `sim/research/milestone_system.gd`. Accept: bot hits all 3 reviews; auto-throttle rule saves seed 3.
- **B4 repair/expeditions purpose** (F5, F6): `data/recipes.json`, `data/contracts.json`, `data/crises.json`, expedition dialog view. Accept: belt repairs > 0 per run; one contract needs an expedition item.
- **B5 readability and phone** (F10, F12; F11 if time): `view/hud*`, `view/panels/*`, `data/weapons.json`/`roles.json`. Accept: wave report shown; overlap-scan test green; squad death delta target.
Order: B1 first (goldens regen), then B2-B5 in parallel; QA r3 table re-run at the end.
