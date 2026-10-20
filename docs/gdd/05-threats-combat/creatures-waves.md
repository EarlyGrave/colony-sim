# Creatures and waves

## Roster `[BUILT]` — `data/enemies.json`, `sim/threats/enemy.gd`, sprites `tools/gen_art.py`
| id | role | notes |
|---|---|---|
| crawler | swarm melee | stage-1 fauna; tutorial raid uses 2 |
| brute | tank, telegraphed slam (aoe) | 2x death burst + shake |
| spitter | ranged acid (line telegraph), `damage_kind` | |
| burrower | erupts under a marked cell, bias to miners | tremor warning |
| mimic | quest-only (Q8/Q15/r4), `name_of_dead`, wears a face | never in raid tables |
| drone_scout / drone_gunner / drone_enforcer | faction `metropolis`, energy damage | see metropolis-raids.md |
Every enemy has `armor {phys, energy}` and `flat` (default 0) so one damage function serves both sides;
`loot` block (creature loot, F2c); `variants` = mutant bands by nest pollution (hp +25 %, dmg +30 %).

## Wave strength `[BUILT]` — `sim/threats/threat_system.gd`, `data/balance.json threat`
Points = `base_strength` 1.2 + `per_wave` 0.7 x index + `per_refined` 0.02 x refined total +
`per_contamination` 0.07 x level + `per_wealth`; x preset `wave_strength_mult` 0.6/1.0/1.15; x quest
`wave_mult` mods; x `strength_mult` from endings (siege madness, Collector assault, pursuit). First wave
capped at 3 points. Raid type by `min_points` + weight (`data/raids.json`: swarm, brute_pack, spitters,
burrowers, scripted `tutorial_audit`). Waves last `wave_duration_ticks` 350 then survivors retreat (D10);
`retreat_fraction` morale. 200-tick warning with an origin arrow (`wave_incoming`), rally letter + HUD strip
1800 ticks before (nest rally).

## Cadence: three clocks `[BUILT]` (pacing batch K, scout pacing.md)
1. **Pollution clock**: next wave in `pollution_interval` lo 0.45 .. hi 0.7 days scaled by contamination:
   clean x10 slower, dirty x0.28 (`dirty_mult`; was 0.5 -> 0.35 -> 0.28 to keep the pillar gap >= 2).
2. **Sentence clock**: audit patrol every 8 / 6 / 4.2 days by preset, independent of pollution (a clean
   colony still meets it). `calm_after_hit_days` 2 / 1 / 0.4 after a wave that hurt. HUD "Next audit in N d".
3. **Essence hoard clock** `[IDEA]` (scout pacing.md): stockpiled essence attracts creatures. Not built.
Plus: scent + dormancy (see scent-lockdown.md), `first_wave_delay_days` 3.5 (gate on shipment 1 is OFF),
awakening after `awaken_mined_total` 60 ore mined or first refine, `quiet_before_wave_ticks` for events.
Waves by d21 (standard_term, K pass): baseline 6.6 / throttle 4.2 / mining-only 4.0; presets short 4.8 /
hard 7.2. Observation (F2c): seeds 1/6/8 get **zero** waves in 60 d with the current bot — check the clock
in the balance pass.

## Nests and the hunger bank `[BUILT]` — `sim/ecology/ecology_system.gd`, `data/ecology.json`
2-4 nests on the map edge; each absorbs local + global pollution into a bank (cap 60); a raid fields
`starved_max` 6 units free and pays `unit_cost` per extra unit, so a clean planet only sends weak waves.
Waves spawn at the fullest nest; mutant variant bands per nest with hysteresis (`revert_ratio`). Chips
raise ecology pressure x1.3 (cap 1.6). Own RNG stream. Rally letter when a nest musters.
`b2_clean_outpost`: clean miners outside pollution are not raid magnets.

## Targeting: threat model v2 `[BUILT]` — `sim/threats/threat_model.gd`, `data/threat.json`
Every building and colonist has a threat value: `base` by type (refinery 10, smelter 8, hq 6, turret 5,
colonist 4...), `state_mod` (working 1.5, firing 2, carrying essence 1.5, chip 2, broken 0.3, burst 3),
pollution here x `k_poll`, distance falloff `d0` 12, sticky target (`stick` 0.7, `pull_ratio` melee 1.3 /
ranged 1.15), per-region cap 40, belts as targets (sqrt belt count, cap 4), `species_bias`. Recomputed every
10 ticks; flow fields + spatial hash for movement (perf batches). Decoys (`decoy.gd`): ash_beacon (burns
waste), penitent_wall, mourning_bell (`trigger_bell` burst), techs `decoys_1/2`. Owner (2026-10-18): the
"attention meter" is MMO-style aggro; players may build tank structures.

## Damage to the line `[BUILT]` — `balance.line_damage`
Belts (hp 40) and machines take bites; stalled belt below 30 %, machine broken below 25 %; repair job
costs 1 plate (`repair_priority` rule modes). Shelter collapse hits (`health.json shelter_collapse`).

## Wave report `[BUILT]` — `view/panels/wave_report_card.gd`
Per-wave card: kills, damage, repelled/timeout; objective met when objectives are on.

## Tools
`tools/balance_report.gd` (waves per seed, repelled, objective met), `tools/kx_pillar_table.gd`,
`tools/qa_r3.gd`, `tools/perf_threat.gd` (300 enemies @ 250x250 ~2.1 ms/tick, budget 2.0 — open).
