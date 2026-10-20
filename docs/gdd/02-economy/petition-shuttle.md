# Petition, audits and the Release Shuttle (the Submit spine)

## Audit Deliveries (tier gates) `[BUILT]` — `sim/research/milestone_system.gd`, `data/milestones.json tiers`
Tiers 0/1 open at start. Tier 2 = deliver 40 plate + 10 parts at the `warden_terminal`
(`deliver_audit`); tier 3 is unlocked by petition phase 3 instead of the 120-plate wall (E). Audit patrols
(creature waves on the sentence clock) are a separate mechanic ([05](../05-threats-combat/creatures-waves.md)).
Bot: tier 2 on 6/10 seeds at 60 d.

## Sentence Commutation Petition `[BUILT]` — `sim/research/petition_system.gd`, `data/petitions.json`
Four staged deliveries after tier 2, preset-scaled amounts (`preset_mult`), `deliver_petition`:
| phase | pays with | reward | waiver (alt, F5) `[BUILT]` |
|---|---|---|---|
| P1 | plates + parts | debt -5 % | Volunteer Detail: 3 inmates, 300 ticks hazardous work, 30 % injury (`detail_job`) |
| P2 | iron + copper ingots | debt -8 %, +15 refined | — |
| P3 | coal + nitrogen (fuel chain) | debt -10 %, unlocks tier 3 | Informant Report: suspicion +25, Informant block -20 |
| P4 | refined essence | debt -25 %, unlocks the gantry | — |
`deliver_petition_alt` takes the waiver. Design (economy doc): on non-Submit paths petitions refuse delivery
once the path is locked `[BUILT]` (`ending_system.gd`); Submit's point of no return = accepting P1.
Bot: P1 0/10 at 60 d today (plates), P4 ~d60 when reached; see balance findings.

## Release Shuttle = Extraction Platform (Submit ending) `[BUILT]` — `sim/shuttle/shuttle_system.gd`, `data/shuttle.json`, flag `s1_enabled`
- After P4: build `release_gantry` (4x4, 800 hp, 20 power, min power factor 0.5), feed 24 release parts
  (standard; x0.6 short / x1.3 hard); each part = 2 plate + 1 refined + 1 fuel_cell (`deliver_shuttle_parts`).
- **Seats** (C3) `[BUILT]`: `seat_parts` 1 per colonist aboard; `set_manifest` leaves people behind
  (unseated stay = Continue colony). Legacy reads freed/stayed from the manifest (F4b).
- Launch window notices (C4) `[BUILT]`: every 8 d after the PoNR +0.1 wave mult, cap 0.5.
- `launch_shuttle` -> 2-day countdown **siege** (waves every 1200 ticks, min 500 when polluted, strength x
  (1 + pollution_frac) "madness peak"); gantry repairable (`repair_gantry`, 1 plate); parts lost 50 % if
  the gantry falls. Win -> "Sentence Ended" screen with the Submit epilogue; Continue keeps playing.
- Old design "2 Metropolis drone-shuttles of goods pickup during the siege" `[IDEA]` (not built).
- `ng_new_names` flag is set by the shuttle but read by nobody (redundant; carry is in `meta.json endings`).

## Bot numbers
Scripted supply bot: launch 4/5 (d29-37). Real factory bot: launch 1/10 at 60 d once (seed 5, RP/FC pass),
0/10 since the bot skips the tutorial at d6 (earlier waves). Shuttle bot sets the Taint cap rule (50 %) to
survive 60 d. Tools: `tools/shuttle_bot.gd`, `tools/petition_bot.gd`, `tools/petition_pace.gd`.

## Old-doc disagreements
- `docs/scout/endgame.md` proposed 100 release parts; shipped 24 (standard).
- Petition phases were planned as "P1 ~d12, P4 ~d35"; real bot sees P1 never, P4 ~d60. Not tuned yet
  (owner: balance pass later).
