# The Metropolis track (drone raids, the Collector)

Status: `[BUILT]` — `sim/threats/metro_track.gd`, `data/balance.json metro` (**enabled: true** since F2e),
`data/raids.json` rows with `faction: "metropolis"` (drone_sweep, collector_drop, collector_assault),
`data/enemies.json drone_*` (energy damage, armour pairs). Note: `data/metro.json` is an empty `{}`; all
numbers live in `balance.json metro`.

## Lore
Creatures are the pollution track (pillar). The Metropolis is a separate **tech track** keyed by
**defiance**, not pollution: essence kept from the quota, refused audits, covert sales. A clean, defiant
colony is still raided; a polluted, obedient one is hit by creatures. The two never share a day
(`grace_days` 1).

## Defiance clock
- +2 per day the quota is unmet (`per_unmet_day`), +10 per declined audit, +0.5 per covert sale;
  decays 3 on days essence was shipped (`decay_on_ship`), max 100.
- Fight path (F2b/F2e): defiance climbs without quota or shipping decay; raids every 3 d
  (`fight_interval_days`) right after a creature wave (`fight_raid_after_wave`), first raid day 8, escalation
  +25 % per raid, `fight_threshold` 60 -> the Collector drop (`collector_relay` lands); after
  `final_after_raids` 4 raids the final assault is possible (`start_assault`).
- Other paths: raid points = `base` 2 + `per_defiance` 0.15 x defiance when defiance >= `min_defiance` 8,
  interval 6 d. Real bot without a path: **0 metro raids** by d60 on 10/10 (as designed).
- Drones `spawn: "drop"` near the HQ/refinery with a tremor warning, ignore nests/dormancy, objective
  `seize` (carry off refined) / `wreck`. Drone loot: 12 % chance, ilvl 6 (`equipment.json sources.drops`).
- Conds for quests: `raids_survived N`, `defiance_over N`; verb `defiance`. Bus `metro_raid_started`.

## Numbers (fight bot, seeds 1-5, 90 d)
Metro raids >= 2 on 6/10 fight-path runs (others die before choosing a path); Uplink built 1/5, relay
dropped 1/5, **Collector win 0/5**: the fight-bot colony dies (few turrets, refined ~0). Blockers found and
fixed: tutorial `waves_held` never released in bot runs; metro needed `not wave_active` while bot waves were
daily. Next balance pass should give the Fight path a real number (F2 acceptance was >= 1/10 Collector win).

## Owner questions
- Energy vs mixed damage for drones (question 9): drone defs carry `damage_kind`; kevlar (phys) is weak
  against them by design, `armor.energy` on gear counters it.
- Does the quota shuttle still land on the Fight path after refusals (question 4)? Today it stops.

## Design doc differences
- threats_pacing.md 2b planned a `metro.json` config and a `siege_platform` raid; built in `balance.json`,
  raids are drone_sweep / collector_drop / collector_assault.
- "Escape raises defiance slowly" — built as `suspicion_per_sale` 0.5 on the metro clock plus the separate
  contraband suspicion meter.
